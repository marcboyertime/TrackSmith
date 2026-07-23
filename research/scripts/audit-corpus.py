#!/usr/bin/env python3
"""Read-only integrity and index-coverage audit for the supplied research corpus."""

from __future__ import annotations

import csv
import hashlib
import sys
import zipfile
from collections import Counter
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
RESEARCH_ROOT = REPO_ROOT / "research"
PAPERS_ROOT = RESEARCH_ROOT / "papers"
EXTRACTED_ROOT = RESEARCH_ROOT / "extracted"
ANALYSIS_ROOT = RESEARCH_ROOT / "analysis"

PART_RANGES = (
    (1, 15),
    (16, 17),
    (18, 30),
    (31, 44),
    (45, 62),
    (63, 67),
    (68, 70),
    (71, 81),
    (82, 82),
)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def is_quarantined(path: Path) -> bool:
    return "quarantine" in path.relative_to(RESEARCH_ROOT).parts


def indexed_hashes(path: Path) -> set[str]:
    with path.open(newline="", encoding="utf-8") as handle:
        return {row["sha256"] for row in csv.DictReader(handle, delimiter="\t")}


def part_name(number: int) -> str:
    for part, (start, end) in enumerate(PART_RANGES, start=1):
        if start <= number <= end:
            return f"TTA-Bench-sources-part-{part:02d}-items-{start:03d}-to-{end:03d}"
    raise ValueError(f"source number outside manifest range: {number}")


def main() -> int:
    failures: list[str] = []
    archive_payload_hashes: set[str] = set()
    archive_member_total = 0
    archive_match_total = 0
    source_index_hashes: set[str] = set()
    manifest_hashes: set[str] = set()

    archives = sorted(PAPERS_ROOT.glob("*.zip"))
    if len(archives) != 10:
        failures.append(f"expected 10 ZIP archives, found {len(archives)}")

    for archive in archives:
        try:
            with zipfile.ZipFile(archive) as bundle:
                corrupt_member = bundle.testzip()
                if corrupt_member is not None:
                    failures.append(f"{archive.name}: CRC failure in {corrupt_member}")

                members = [info for info in bundle.infolist() if not info.is_dir()]
                archive_member_total += len(members)
                matched = 0
                expected_relative_paths: set[Path] = set()
                for member in members:
                    data = bundle.read(member)
                    digest = sha256_bytes(data)
                    archive_payload_hashes.add(digest)
                    expected = EXTRACTED_ROOT / archive.stem / member.filename
                    expected_relative_paths.add(Path(member.filename))
                    if not expected.is_file():
                        failures.append(f"{archive.name}: missing extracted member {member.filename}")
                        continue
                    if sha256_file(expected) != digest:
                        failures.append(f"{archive.name}: extracted hash mismatch {member.filename}")
                        continue
                    matched += 1

                    if member.filename == "source_index.csv":
                        source_index_hashes.add(digest)
                    elif member.filename == "notebooklm_backup_manifest.json":
                        manifest_hashes.add(digest)

                archive_match_total += matched
                extracted_root = EXTRACTED_ROOT / archive.stem
                extras = []
                if extracted_root.is_dir():
                    extras = sorted(
                        path.relative_to(extracted_root).as_posix()
                        for path in extracted_root.rglob("*")
                        if path.is_file() and path.relative_to(extracted_root) not in expected_relative_paths
                    )
                extras_note = f"; extra extracted files: {', '.join(extras)}" if extras else ""
                print(f"PASS {archive.name}: {matched}/{len(members)} members hash-match{extras_note}")
        except zipfile.BadZipFile as error:
            failures.append(f"{archive.name}: invalid ZIP: {error}")

    if len(source_index_hashes) != 1:
        failures.append(f"TTA source_index.csv copies have {len(source_index_hashes)} distinct hashes")
    if len(manifest_hashes) != 1:
        failures.append(f"TTA notebook manifests have {len(manifest_hashes)} distinct hashes")

    source_index = (
        EXTRACTED_ROOT
        / "TTA-Bench-sources-part-01-items-001-to-015"
        / "source_index.csv"
    )
    with source_index.open(newline="", encoding="utf-8-sig") as handle:
        rows = list(csv.DictReader(handle))

    numbers = [int(row["number"]) for row in rows]
    if numbers != list(range(1, 83)):
        failures.append("TTA source index is not the contiguous range 1...82")

    index_by_format = {
        "PDF": indexed_hashes(ANALYSIS_ROOT / "corpus-index.tsv"),
        "HTML": indexed_hashes(ANALYSIS_ROOT / "html-index.tsv"),
        "TXT": indexed_hashes(ANALYSIS_ROOT / "source-text-index.tsv"),
    }
    formats: Counter[str] = Counter()
    statuses: Counter[str] = Counter()
    source_payload_hashes: set[str] = set()
    empty_slots: list[int] = []

    for row in rows:
        number = int(row["number"])
        source_format = row["format"]
        formats[source_format] += 1
        statuses[row["status"]] += 1
        source = EXTRACTED_ROOT / part_name(number) / "sources" / row["file"]
        if not source.is_file():
            failures.append(f"source slot {number:03d}: missing {source.relative_to(REPO_ROOT)}")
            continue
        digest = sha256_file(source)
        source_payload_hashes.add(digest)
        if source.stat().st_size == 0:
            empty_slots.append(number)
        if source_format not in index_by_format:
            failures.append(f"source slot {number:03d}: unsupported format {source_format}")
        elif digest not in index_by_format[source_format]:
            failures.append(f"source slot {number:03d}: payload hash absent from {source_format} index")

    all_pdf_paths = list(RESEARCH_ROOT.rglob("*.pdf"))
    all_html_paths = list(RESEARCH_ROOT.rglob("*.html")) + list(RESEARCH_ROOT.rglob("*.htm"))
    pdf_paths = [path for path in all_pdf_paths if not is_quarantined(path)]
    html_paths = [path for path in all_html_paths if not is_quarantined(path)]
    quarantined_pdf_paths = [path for path in all_pdf_paths if is_quarantined(path)]
    quarantined_html_paths = [path for path in all_html_paths if is_quarantined(path)]
    pdf_hashes = {sha256_file(path) for path in pdf_paths}
    html_hashes = {sha256_file(path) for path in html_paths}

    indexed_pdf_hashes = index_by_format["PDF"]
    indexed_html_hashes = index_by_format["HTML"]
    if indexed_pdf_hashes != pdf_hashes:
        failures.append(
            "PDF index does not exactly match non-quarantined live payloads "
            f"(indexed={len(indexed_pdf_hashes)}, live={len(pdf_hashes)})"
        )
    if indexed_html_hashes != html_hashes:
        failures.append(
            "HTML index does not exactly match non-quarantined live payloads "
            f"(indexed={len(indexed_html_hashes)}, live={len(html_hashes)})"
        )

    print(
        f"ARCHIVES {len(archives)}; MEMBERS {archive_member_total}; "
        f"MATCHED {archive_match_total}; UNIQUE_ARCHIVE_PAYLOADS {len(archive_payload_hashes)}"
    )
    print(
        f"TTA_SLOTS {len(rows)}; FORMATS {dict(formats)}; STATUSES {dict(statuses)}; "
        f"UNIQUE_SOURCE_PAYLOADS {len(source_payload_hashes)}; EMPTY_SLOTS {empty_slots}"
    )
    print(
        f"SEARCHABLE_PDF_PATHS {len(pdf_paths)}; UNIQUE_PDFS {len(pdf_hashes)}; "
        f"QUARANTINED_PDF_PATHS {len(quarantined_pdf_paths)}; "
        f"SEARCHABLE_HTML_PATHS {len(html_paths)}; UNIQUE_HTML_HASHES {len(html_hashes)}; "
        f"QUARANTINED_HTML_PATHS {len(quarantined_html_paths)}"
    )

    if failures:
        for failure in failures:
            print(f"FAIL {failure}", file=sys.stderr)
        return 1

    print("PASS corpus archive integrity, extraction equivalence, source slots, and index coverage")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
