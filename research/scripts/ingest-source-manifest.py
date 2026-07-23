#!/usr/bin/env python3
"""Batch TrackSmith sources through the repository's fail-closed ingest CLI.

The JSONL declaration remains the rich research catalog. The Swift archive
remains authoritative for transport validation, immutable payload storage, and
capture audit history. This wrapper joins both records without weakening either
boundary.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import tempfile
from datetime import UTC, datetime
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_ARCHIVE = REPO_ROOT / "research" / "library" / "tracksmith-research-archive"
DEFAULT_RESULTS = REPO_ROOT / "research" / "metadata" / "ingestion-results.jsonl"

REQUIRED_FIELDS = {
    "resource_id",
    "title",
    "publisher_or_authors",
    "evidence_role",
    "canonical_url",
    "retrieval_url",
    "source_version",
    "capture_mode",
    "handling_class",
    "rights_basis",
    "license_status",
    "local_use_only",
    "source_class",
    "evidence_class",
    "review_depth",
    "reliability_assessment",
    "tracksmith_relevance",
    "topics",
}

PAYLOAD_MODES = {"pdf", "html", "text", "binary"}
METADATA_MODES = {"gitCheckout", "linkAndNotes"}
VALID_MODES = PAYLOAD_MODES | METADATA_MODES

DEFAULT_THRESHOLDS = {
    "pdf": {
        "expected_media_types": ["application/pdf"],
        "minimum_byte_count": 10_000,
        "minimum_page_count": 2,
        "minimum_useful_text_characters": 500,
        "requires_extractable_text": True,
    },
    "html": {
        "expected_media_types": ["text/html", "application/xhtml+xml"],
        "minimum_byte_count": 1_000,
        "minimum_page_count": 1,
        "minimum_useful_text_characters": 500,
        "requires_extractable_text": True,
    },
    "text": {
        "expected_media_types": ["text/plain", "text/csv", "application/json"],
        "minimum_byte_count": 200,
        "minimum_page_count": 1,
        "minimum_useful_text_characters": 100,
        "requires_extractable_text": True,
    },
    "binary": {
        "expected_media_types": ["application/octet-stream"],
        "minimum_byte_count": 1,
        "minimum_page_count": 1,
        "minimum_useful_text_characters": 0,
        "requires_extractable_text": False,
    },
    "gitCheckout": {
        "expected_media_types": ["application/vnd.git"],
        "minimum_byte_count": 1,
        "minimum_page_count": 1,
        "minimum_useful_text_characters": 0,
        "requires_extractable_text": False,
    },
    "linkAndNotes": {
        "expected_media_types": ["text/uri-list"],
        "minimum_byte_count": 1,
        "minimum_page_count": 1,
        "minimum_useful_text_characters": 0,
        "requires_extractable_text": False,
    },
}


def utc_now() -> str:
    return datetime.now(UTC).isoformat().replace("+00:00", "Z")


def load_manifest(path: Path) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    identifiers: set[str] = set()
    with path.open(encoding="utf-8") as handle:
        for line_number, raw_line in enumerate(handle, start=1):
            stripped = raw_line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            try:
                record = json.loads(stripped)
            except json.JSONDecodeError as error:
                raise ValueError(f"{path}:{line_number}: invalid JSON: {error}") from error
            if not isinstance(record, dict):
                raise ValueError(f"{path}:{line_number}: each JSONL record must be an object")
            missing = sorted(REQUIRED_FIELDS - set(record))
            if missing:
                raise ValueError(f"{path}:{line_number}: missing required fields: {missing}")
            resource_id = record["resource_id"]
            if not isinstance(resource_id, str) or not resource_id:
                raise ValueError(f"{path}:{line_number}: resource_id must be a non-empty string")
            if resource_id in identifiers:
                raise ValueError(f"{path}:{line_number}: duplicate resource_id {resource_id}")
            identifiers.add(resource_id)
            mode = record["capture_mode"]
            if mode not in VALID_MODES:
                raise ValueError(f"{path}:{line_number}: unsupported capture_mode {mode!r}")
            if not isinstance(record["topics"], list) or not all(
                isinstance(topic, str) and topic for topic in record["topics"]
            ):
                raise ValueError(f"{path}:{line_number}: topics must be a list of non-empty strings")
            if mode == "gitCheckout" and not record.get("checkout_path"):
                raise ValueError(f"{path}:{line_number}: gitCheckout requires checkout_path")
            record["_manifest_line"] = line_number
            records.append(record)
    if not records:
        raise ValueError(f"{path}: manifest contains no source records")
    return records


def build_request(source: dict[str, Any]) -> dict[str, Any]:
    mode = source["capture_mode"]
    defaults = DEFAULT_THRESHOLDS[mode]
    return {
        "resourceID": source["resource_id"],
        "title": source["title"],
        "publisherOrAuthors": source["publisher_or_authors"],
        "evidenceRole": source["evidence_role"],
        "canonicalURL": source["canonical_url"],
        "retrievalURL": source["retrieval_url"],
        "sourceVersion": source["source_version"],
        "captureMode": mode,
        "expectedMediaTypes": source.get(
            "expected_media_types", defaults["expected_media_types"]
        ),
        "minimumByteCount": source.get(
            "minimum_byte_count", defaults["minimum_byte_count"]
        ),
        "minimumPageCount": source.get(
            "minimum_page_count", defaults["minimum_page_count"]
        ),
        "minimumUsefulTextCharacters": source.get(
            "minimum_useful_text_characters",
            defaults["minimum_useful_text_characters"],
        ),
        "requiresExtractableText": source.get(
            "requires_extractable_text", defaults["requires_extractable_text"]
        ),
        "handlingClass": source["handling_class"],
        "rightsBasis": source["rights_basis"],
        "licenseStatus": source["license_status"],
        "licenseSPDX": source.get("license_spdx"),
        "localUseOnly": source["local_use_only"],
        "replacementPolicy": source.get(
            "replacement_policy", "rejectDifferentPayload"
        ),
        "supersedesSHA256": source.get("supersedes_sha256"),
        "replacementReason": source.get("replacement_reason"),
        "notes": source.get("notes", ""),
    }


def cli_command(
    cli: Path,
    source: dict[str, Any],
    request_path: Path,
    archive_root: Path,
) -> list[str]:
    mode = source["capture_mode"]
    if mode in PAYLOAD_MODES:
        return [str(cli), "fetch", str(request_path), str(archive_root)]
    if mode == "linkAndNotes":
        return [str(cli), "link", str(request_path), str(archive_root)]
    command = [
        str(cli),
        "git",
        str((REPO_ROOT / source["checkout_path"]).resolve()),
        str(archive_root),
    ]
    if source.get("expected_commit"):
        command.append(source["expected_commit"])
    return command


def public_source_metadata(source: dict[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in source.items() if not key.startswith("_")}


def append_result(path: Path, result: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(result, sort_keys=True, ensure_ascii=True) + "\n")
        handle.flush()


def run() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--archive-root", type=Path, default=DEFAULT_ARCHIVE)
    parser.add_argument("--results", type=Path, default=DEFAULT_RESULTS)
    parser.add_argument("--continue-on-error", action="store_true")
    parser.add_argument(
        "--resource-id",
        action="append",
        dest="resource_ids",
        help="Process only the named resource_id; may be repeated.",
    )
    arguments = parser.parse_args()

    manifest = arguments.manifest.resolve()
    archive_root = arguments.archive_root.resolve()
    results_path = arguments.results.resolve()
    sources = load_manifest(manifest)
    if arguments.resource_ids:
        requested = set(arguments.resource_ids)
        available = {source["resource_id"] for source in sources}
        missing = sorted(requested - available)
        if missing:
            raise ValueError(f"resource_id values were not present in the manifest: {missing}")
        sources = [source for source in sources if source["resource_id"] in requested]

    subprocess.run(
        ["swift", "build", "--product", "ResearchIngestCLI"],
        cwd=REPO_ROOT,
        check=True,
    )
    bin_path = subprocess.run(
        ["swift", "build", "--show-bin-path"],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    cli = Path(bin_path) / "ResearchIngestCLI"

    failures = 0
    with tempfile.TemporaryDirectory(prefix="tracksmith-source-ingest-") as temp:
        temp_root = Path(temp)
        for source in sources:
            request_path = temp_root / f"{source['resource_id']}.json"
            request_path.write_text(
                json.dumps(build_request(source), indent=2, ensure_ascii=True) + "\n",
                encoding="utf-8",
            )
            command = cli_command(cli, source, request_path, archive_root)
            started_at = utc_now()
            completed = subprocess.run(
                command,
                cwd=REPO_ROOT,
                capture_output=True,
                text=True,
            )
            result: dict[str, Any] = {
                "result_version": "1.0",
                "manifest_path": str(manifest.relative_to(REPO_ROOT)),
                "manifest_line": source["_manifest_line"],
                "attempted_at_utc": started_at,
                "source": public_source_metadata(source),
                "success": completed.returncode == 0,
            }
            if completed.returncode == 0:
                result["capture_record"] = json.loads(completed.stdout)
            else:
                failures += 1
                result["error"] = completed.stderr.strip() or completed.stdout.strip()
            append_result(results_path, result)
            status = "PASS" if completed.returncode == 0 else "FAIL"
            print(f"{status} {source['resource_id']}")
            if completed.returncode != 0 and not arguments.continue_on_error:
                break

    print(
        f"Processed {len(sources) if failures == 0 else 'manifest with failures'}; "
        f"failures={failures}; results={results_path.relative_to(REPO_ROOT)}"
    )
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(run())
