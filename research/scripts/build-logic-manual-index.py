#!/usr/bin/env python3
"""Build a provenance-preserving index of the archived Logic Pro manuals.

The index contains document metadata and PDF outline headings only. It does not
copy Apple manual prose. Review status is deliberately absent: indexing a
heading is not evidence that its underlying section was deeply reviewed.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import subprocess
from dataclasses import dataclass
from typing import Any


REPOSITORY_ROOT = pathlib.Path(__file__).resolve().parents[2]
DEFAULT_ARCHIVE = REPOSITORY_ROOT / "research/papers/tracksmith-logic-12.3-archive"
DEFAULT_OUTPUT = REPOSITORY_ROOT / "research/knowledge/logic-pro-12.3-manual-index.json"


@dataclass(frozen=True)
class Manual:
    identifier: str
    manifest_slug: str
    title: str
    sha256: str
    expected_pages: int


MANUALS = (
    Manual(
        "effects",
        "effects-guide",
        "Logic Pro Effects for Mac",
        "b317e4bd9b69238c85040723fa11f14eed7ac58d12ac64cb055fd2e8e342f819",
        390,
    ),
    Manual(
        "instruments",
        "instruments-guide",
        "Logic Pro Instruments for Mac",
        "fc867e61b1bbcfc16d4ba98058f7cde104ec17e0649026769c308cff07049ab4",
        752,
    ),
    Manual(
        "user-guide",
        "user-guide",
        "Logic Pro User Guide for Mac",
        "aa016d18d7e4f3559cdec54a99937d00b379617fee87510db1ec9853a4996cff",
        1324,
    ),
    Manual(
        "control-surfaces",
        "control-surfaces-guide",
        "Control Surfaces Support Guide for Logic Pro",
        "5ab5e4ef38e9c8e9279a0a2d36dcaabd1a9471942843d0162a3016f6ebf9322c",
        220,
    ),
)


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--archive", type=pathlib.Path, default=DEFAULT_ARCHIVE)
    parser.add_argument("--output", type=pathlib.Path, default=DEFAULT_OUTPUT)
    return parser.parse_args()


def file_hash(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def qpdf_outline(path: pathlib.Path) -> list[dict[str, Any]]:
    result = subprocess.run(
        ["qpdf", "--json", "--json-key=outlines", str(path)],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)["outlines"]


def flatten_outline(
    nodes: list[dict[str, Any]],
    parent_path: tuple[str, ...] = (),
    depth: int = 0,
) -> list[dict[str, Any]]:
    flattened: list[dict[str, Any]] = []
    for node in nodes:
        title = " ".join(str(node.get("title", "")).replace("\u00a0", " ").split())
        page = int(node.get("destpageposfrom1", 0))
        if not title or page <= 0:
            continue
        path = parent_path + (title,)
        flattened.append(
            {
                "path": list(path),
                "pathText": " > ".join(path),
                "title": title,
                "pageStart": page,
                "depth": depth,
            }
        )
        flattened.extend(flatten_outline(node.get("kids", []), path, depth + 1))
    return flattened


def deduplicate(entries: list[dict[str, Any]]) -> list[dict[str, Any]]:
    seen: set[tuple[str, int]] = set()
    result: list[dict[str, Any]] = []
    for entry in entries:
        key = (entry["pathText"], entry["pageStart"])
        if key not in seen:
            seen.add(key)
            result.append(entry)
    return result


def add_page_ends(entries: list[dict[str, Any]], page_count: int) -> None:
    for index, entry in enumerate(entries):
        start = entry["pageStart"]
        next_page = page_count + 1
        for later in entries[index + 1 :]:
            if later["pageStart"] > start and later["depth"] <= entry["depth"]:
                next_page = later["pageStart"]
                break
        entry["pageEnd"] = max(start, min(page_count, next_page - 1))


def load_audit(archive: pathlib.Path, manifest_slug: str) -> dict[str, Any]:
    path = archive / "manifests/current" / f"apple-logic-pro-12.3-{manifest_slug}-current.json"
    return json.loads(path.read_text(encoding="utf-8"))


def build_manual(archive: pathlib.Path, manual: Manual) -> dict[str, Any]:
    path = archive / "objects" / f"{manual.sha256}.pdf"
    if not path.is_file():
        raise SystemExit(f"missing immutable source: {path}")
    actual_hash = file_hash(path)
    if actual_hash != manual.sha256:
        raise SystemExit(f"hash mismatch for {path}: {actual_hash}")

    audit = load_audit(archive, manual.manifest_slug)
    if audit.get("captureStatus") != "accepted" or audit.get("qualityStatus") != "validated":
        raise SystemExit(f"source is not accepted and validated: {manual.identifier}")

    entries = deduplicate(flatten_outline(qpdf_outline(path)))
    add_page_ends(entries, manual.expected_pages)
    return {
        "identifier": manual.identifier,
        "title": manual.title,
        "sourceVersion": audit["sourceVersion"],
        "canonicalURL": audit["canonicalURL"],
        "retrievalURL": audit["retrievalURL"],
        "retrievedAtUTC": audit["retrievedAtUTC"],
        "sha256": actual_hash,
        "byteCount": audit["byteCount"],
        "pageCount": manual.expected_pages,
        "handlingClass": audit["handlingClass"],
        "licenseStatus": audit["licenseStatus"],
        "localUseOnly": audit["localUseOnly"],
        "qualityStatus": audit["qualityStatus"],
        "outlineEntryCount": len(entries),
        "outlineEntries": entries,
    }


def main() -> int:
    arguments = parse_arguments()
    manuals = [build_manual(arguments.archive, manual) for manual in MANUALS]
    result = {
        "schemaVersion": "1.0",
        "knowledgeStatus": "source_index_only_not_deep_review_evidence",
        "product": "TrackSmith",
        "logicVersionContext": "Logic Pro for Mac 12.3 selected in Apple's live guide at retrieval",
        "copyrightNotice": (
            "Index metadata only. Underlying Apple manuals are local-use-only internal references; "
            "no redistribution or training rights are inferred."
        ),
        "manualCount": len(manuals),
        "totalPageCount": sum(manual["pageCount"] for manual in manuals),
        "totalOutlineEntryCount": sum(manual["outlineEntryCount"] for manual in manuals),
        "manuals": manuals,
    }
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(
        f"wrote {arguments.output}: {result['manualCount']} manuals, "
        f"{result['totalPageCount']} pages, {result['totalOutlineEntryCount']} unique outline entries"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
