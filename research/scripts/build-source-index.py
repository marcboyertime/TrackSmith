#!/usr/bin/env python3
"""Build TrackSmith's deterministic, quarantine-safe baseline source ledger.

The immutable ResearchIngestion archives remain authoritative for transport and
payload validation. This script projects those archives, the supplied legacy
corpus, and available source declarations into one record per byte-unique source
payload. Link-only and Git-pinned current records are retained as metadata-only
records. Unknown bibliographic or assessment fields stay explicitly null or
"unknown"; filenames are never promoted into asserted titles.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Iterable


REPO_ROOT = Path(__file__).resolve().parents[2]
RESEARCH_ROOT = REPO_ROOT / "research"
DEFAULT_SOURCE_INDEX = RESEARCH_ROOT / "metadata" / "SOURCE_INDEX.jsonl"
DEFAULT_BIBLIOGRAPHY = RESEARCH_ROOT / "metadata" / "BIBLIOGRAPHY.json"
SCHEMA_VERSION = "tracksmith.source-index.v1"

ARCHIVES = (
    (
        "general",
        RESEARCH_ROOT / "library" / "tracksmith-research-archive",
    ),
    (
        "producer_judgment",
        RESEARCH_ROOT / "papers" / "tracksmith-producer-judgment-archive",
    ),
    (
        "logic_12_3",
        RESEARCH_ROOT / "papers" / "tracksmith-logic-12.3-archive",
    ),
)

TTA_PART_RANGES = (
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

MEDIA_TYPES = {
    ".pdf": "application/pdf",
    ".html": "text/html",
    ".htm": "text/html",
    ".txt": "text/plain",
    ".csv": "text/csv",
    ".json": "application/json",
    ".jsonl": "application/x-ndjson",
    ".zip": "application/zip",
    ".wav": "audio/wav",
    ".aif": "audio/aiff",
    ".aiff": "audio/aiff",
    ".flac": "audio/flac",
    ".mp3": "audio/mpeg",
    ".mp4": "video/mp4",
    ".mov": "video/quicktime",
    ".bin": "application/octet-stream",
}

SCALAR_FIELDS = (
    "title",
    "organization_or_assignee",
    "publisher_or_authors_raw",
    "publication_or_priority_date",
    "publication_date",
    "priority_date",
    "source_class",
    "evidence_class",
    "evidence_role",
    "canonical_url",
    "retrieval_url",
    "retrieved_at_utc",
    "document_version",
    "patent_family_id",
    "work_family_id",
    "accessibility_status",
    "rights_status",
    "rights_basis",
    "handling_class",
    "license_status",
    "license_spdx",
    "local_use_only",
    "review_depth",
    "reliability_assessment",
    "tracksmith_relevance",
    "capture_mode",
    "media_type",
    "capture_status",
    "quality_status",
    "git_commit",
    "git_remote_url",
    "placeholder_sha256",
    "supersedes_sha256",
)

LIST_FIELDS = (
    "authors_or_inventors",
    "topics",
    "resource_ids",
    "quality_findings",
    "relevance_notes",
    "placeholder_paths",
)

NULL_DEFAULT_FIELDS = {
    "title",
    "organization_or_assignee",
    "publisher_or_authors_raw",
    "publication_or_priority_date",
    "publication_date",
    "priority_date",
    "canonical_url",
    "retrieval_url",
    "retrieved_at_utc",
    "document_version",
    "patent_family_id",
    "work_family_id",
    "rights_basis",
    "license_spdx",
    "local_use_only",
    "tracksmith_relevance",
    "git_commit",
    "git_remote_url",
    "placeholder_sha256",
    "supersedes_sha256",
}


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-index", type=Path, default=DEFAULT_SOURCE_INDEX)
    parser.add_argument("--bibliography", type=Path, default=DEFAULT_BIBLIOGRAPHY)
    return parser.parse_args()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def sha256_text(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def relative_path(path: Path) -> str:
    return path.resolve().relative_to(REPO_ROOT).as_posix()


def is_relative_to(path: Path, root: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except ValueError:
        return False


def has_quarantine_component(path: Path | str) -> bool:
    parts = Path(path).parts
    return any(part.lower() == "quarantine" for part in parts)


def media_type_for(path: Path) -> str:
    return MEDIA_TYPES.get(path.suffix.lower(), "application/octet-stream")


def useful(value: Any) -> bool:
    if value is None or value == "" or value == "unknown":
        return False
    if isinstance(value, (list, dict, tuple, set)) and not value:
        return False
    return True


def list_values(value: Any) -> list[str]:
    if value is None:
        return []
    if isinstance(value, str):
        return [value] if value.strip() else []
    if isinstance(value, list):
        return [str(item) for item in value if str(item).strip()]
    return [str(value)]


def split_people(value: Any) -> list[str]:
    if isinstance(value, list):
        return sorted({str(item).strip() for item in value if str(item).strip()})
    if not isinstance(value, str) or not value.strip():
        return []
    if ";" not in value:
        return []
    return sorted({part.strip() for part in value.split(";") if part.strip()})


def organization_from_raw(value: Any) -> str | None:
    if not isinstance(value, str) or not value.strip() or ";" in value:
        return None
    markers = (
        " inc.",
        " ltd",
        " llc",
        " corporation",
        " university",
        " institute",
        " association",
        " union",
        " society",
    )
    lower = f" {value.strip().lower()}"
    return value.strip() if any(marker in lower for marker in markers) else None


def rights_status(
    explicit: Any,
    handling_class: Any,
    local_use_only: Any,
) -> str:
    if useful(explicit):
        return str(explicit)
    if local_use_only is True:
        return "local-use-only"
    mapping = {
        "redistributable": "redistribution-permitted",
        "internalReference": "local-use-only",
        "linkAndNotes": "link-and-notes-only",
        "licenseReviewRequired": "unclear-review-required",
    }
    return mapping.get(str(handling_class), "unknown")


def normalized_review_depth(value: Any) -> str:
    if not useful(value):
        return "unknown"
    normalized = re.sub(r"[^a-z0-9]+", "_", str(value).lower()).strip("_")
    return normalized or "unknown"


def make_fact(priority: int, origin: str, **values: Any) -> dict[str, Any]:
    fact = {"_priority": priority, "_origin": origin}
    fact.update(values)
    return fact


def normalize_source_declaration(
    source: dict[str, Any],
    origin: str,
    priority: int = 100,
) -> dict[str, Any]:
    raw_identity = source.get("publisher_or_authors") or source.get(
        "publisherOrAuthors"
    )
    source_class = source.get("source_class", "unknown")
    authors = source.get("authors_or_inventors") or source.get("authors")
    if not authors and (
        "paper" in str(source_class).lower()
        or "patent" in str(source_class).lower()
        or "arxiv.org" in str(source.get("canonical_url", ""))
    ):
        authors = split_people(raw_identity)
    organization = (
        source.get("organization_or_assignee")
        or source.get("organization")
        or source.get("assignee")
    )
    if not organization:
        organization = organization_from_raw(raw_identity)
    publication_date = source.get("publication_date")
    priority_date = source.get("priority_date")
    combined_date = source.get("publication_or_priority_date")
    if not combined_date:
        combined_date = (
            priority_date
            if "patent" in str(source_class).lower() and priority_date
            else publication_date or source.get("year") or priority_date
        )
    handling = source.get("handling_class") or source.get("handlingClass")
    local_only = source.get("local_use_only")
    if local_only is None:
        local_only = source.get("localUseOnly")
    return make_fact(
        priority,
        origin,
        title=source.get("title"),
        authors_or_inventors=list_values(authors),
        organization_or_assignee=organization,
        publisher_or_authors_raw=raw_identity,
        publication_or_priority_date=combined_date,
        publication_date=publication_date,
        priority_date=priority_date,
        source_class=source_class,
        evidence_class=source.get("evidence_class", "unknown"),
        evidence_role=source.get("evidence_role") or source.get("evidenceRole"),
        canonical_url=source.get("canonical_url") or source.get("canonicalURL"),
        retrieval_url=source.get("retrieval_url") or source.get("retrievalURL"),
        retrieved_at_utc=source.get("retrieved_at_utc")
        or source.get("retrievedAtUTC"),
        document_version=source.get("document_version")
        or source.get("source_version")
        or source.get("sourceVersion"),
        patent_family_id=source.get("patent_family_id")
        or source.get("patent_family"),
        work_family_id=source.get("work_family_id"),
        accessibility_status=source.get("accessibility_status", "unknown"),
        rights_status=rights_status(
            source.get("rights_status"), handling, local_only
        ),
        rights_basis=source.get("rights_basis") or source.get("rightsBasis"),
        handling_class=handling,
        license_status=source.get("license_status") or source.get("licenseStatus"),
        license_spdx=source.get("license_spdx") or source.get("licenseSPDX"),
        local_use_only=local_only,
        review_depth=normalized_review_depth(source.get("review_depth")),
        reliability_assessment=source.get("reliability_assessment", "unknown"),
        tracksmith_relevance=source.get("tracksmith_relevance"),
        topics=sorted(set(list_values(source.get("topics")))),
        resource_ids=list_values(
            source.get("resource_id") or source.get("resourceID")
        ),
        capture_mode=source.get("capture_mode") or source.get("captureMode"),
        media_type=source.get("media_type") or source.get("mediaType"),
        capture_status=source.get("capture_status") or source.get("captureStatus"),
        quality_status=source.get("quality_status") or source.get("qualityStatus"),
        quality_findings=list_values(
            source.get("quality_findings") or source.get("qualityFindings")
        ),
        git_commit=source.get("git_commit") or source.get("gitCommit"),
        git_remote_url=source.get("git_remote_url") or source.get("gitRemoteURL"),
        placeholder_sha256=source.get("placeholder_sha256"),
        placeholder_paths=list_values(source.get("placeholder_paths")),
        supersedes_sha256=source.get("supersedes_sha256")
        or source.get("supersedesSHA256"),
    )


def normalize_capture(
    capture: dict[str, Any],
    archive_label: str,
    origin: str,
    priority: int,
) -> dict[str, Any]:
    raw_identity = capture.get("publisherOrAuthors")
    if archive_label == "producer_judgment":
        source_class = "academic_paper"
        evidence_class = "unknown"
        authors = split_people(raw_identity)
        organization = None
    elif archive_label == "logic_12_3":
        source_class = "official_manual"
        evidence_class = "official documented product behavior"
        authors = []
        organization = raw_identity
    else:
        source_class = "unknown"
        evidence_class = "unknown"
        authors = []
        organization = organization_from_raw(raw_identity)
    capture_status = capture.get("captureStatus")
    quality_status = capture.get("qualityStatus")
    accessibility = "unknown"
    if capture_status in {"accepted", "duplicate"} and quality_status == "validated":
        accessibility = "retrieved"
    elif capture_status in {"linkOnly", "gitPinned"}:
        accessibility = "metadata-only"
    handling = capture.get("handlingClass")
    local_only = capture.get("localUseOnly")
    return make_fact(
        priority,
        origin,
        title=capture.get("title"),
        authors_or_inventors=authors,
        organization_or_assignee=organization,
        publisher_or_authors_raw=raw_identity,
        publication_or_priority_date=None,
        source_class=source_class,
        evidence_class=evidence_class,
        evidence_role=capture.get("evidenceRole"),
        canonical_url=capture.get("canonicalURL"),
        retrieval_url=capture.get("retrievalURL"),
        retrieved_at_utc=capture.get("retrievedAtUTC"),
        document_version=capture.get("sourceVersion"),
        patent_family_id=None,
        work_family_id=None,
        accessibility_status=accessibility,
        rights_status=rights_status(None, handling, local_only),
        rights_basis=capture.get("rightsBasis"),
        handling_class=handling,
        license_status=capture.get("licenseStatus"),
        license_spdx=capture.get("licenseSPDX"),
        local_use_only=local_only,
        review_depth="unknown",
        reliability_assessment=(
            "high_official_primary_source"
            if archive_label == "logic_12_3"
            else "unknown"
        ),
        tracksmith_relevance=capture.get("evidenceRole"),
        topics=[],
        resource_ids=list_values(capture.get("resourceID")),
        capture_mode=capture.get("captureMode"),
        media_type=capture.get("mediaType"),
        capture_status=capture_status,
        quality_status=quality_status,
        quality_findings=list_values(capture.get("qualityFindings")),
        git_commit=capture.get("gitCommit"),
        git_remote_url=capture.get("gitRemoteURL"),
        placeholder_sha256=None,
        placeholder_paths=[],
        supersedes_sha256=capture.get("supersedesSHA256"),
    )


def merge_facts(facts: Iterable[dict[str, Any]]) -> dict[str, Any]:
    ordered = sorted(
        facts,
        key=lambda fact: (-int(fact["_priority"]), str(fact["_origin"])),
    )
    result: dict[str, Any] = {}
    for field in SCALAR_FIELDS:
        values = [fact.get(field) for fact in ordered if useful(fact.get(field))]
        result[field] = values[0] if values else (
            None if field in NULL_DEFAULT_FIELDS else "unknown"
        )
    for field in LIST_FIELDS:
        values: set[str] = set()
        for fact in ordered:
            values.update(list_values(fact.get(field)))
        result[field] = (
            sorted(values)
            if values or field != "authors_or_inventors"
            else None
        )

    for field, alternate_field in (
        ("title", "alternate_titles"),
        ("canonical_url", "alternate_canonical_urls"),
        ("retrieval_url", "alternate_retrieval_urls"),
        ("document_version", "alternate_document_versions"),
    ):
        primary = result[field]
        alternates = {
            str(fact[field])
            for fact in ordered
            if useful(fact.get(field)) and fact[field] != primary
        }
        result[alternate_field] = sorted(alternates)
    result["metadata_sources"] = sorted(
        {str(fact["_origin"]) for fact in ordered}
    )
    return result


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def read_jsonl(path: Path) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    with path.open(encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, start=1):
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            value = json.loads(stripped)
            if not isinstance(value, dict):
                raise ValueError(f"{path}:{line_number}: expected JSON object")
            records.append(value)
    return records


def add_payload_path(
    path: Path,
    payload_paths: dict[str, set[str]],
    payload_sizes: dict[str, int],
) -> str:
    if has_quarantine_component(path):
        raise ValueError(f"refusing to index quarantine path: {path}")
    if not path.is_file():
        raise ValueError(f"source payload is missing: {path}")
    digest = sha256_file(path)
    relative = relative_path(path)
    payload_paths[digest].add(relative)
    size = path.stat().st_size
    previous_size = payload_sizes.get(digest)
    if previous_size is not None and previous_size != size:
        raise ValueError(f"SHA-256 size invariant failed for {digest}")
    payload_sizes[digest] = size
    return digest


def path_preference(value: str) -> tuple[int, str]:
    if value.startswith("research/library/tracksmith-research-archive/objects/"):
        rank = 0
    elif value.startswith(
        "research/papers/tracksmith-producer-judgment-archive/objects/"
    ):
        rank = 1
    elif value.startswith("research/papers/tracksmith-logic-12.3-archive/objects/"):
        rank = 2
    elif value.startswith("research/papers/") and "/sources/" not in value:
        rank = 3
    elif value.startswith("research/extracted/"):
        rank = 4
    elif value.startswith("research/papers/"):
        rank = 5
    elif value.startswith("research/library/"):
        rank = 6
    elif value.startswith("TrackSmith_Producer_Judgment_Expansion/"):
        rank = 7
    else:
        rank = 8
    return rank, value


def archive_manifests(root: Path) -> list[tuple[Path, bool]]:
    history = sorted((root / "manifests" / "history").glob("*.json"))
    current = sorted((root / "manifests" / "current").glob("*.json"))
    return [(path, False) for path in history] + [
        (path, True) for path in current
    ]


def discover_archives(
    payload_paths: dict[str, set[str]],
    payload_sizes: dict[str, int],
    facts_by_sha: dict[str, list[dict[str, Any]]],
) -> tuple[list[dict[str, Any]], dict[str, set[str]], list[dict[str, Any]]]:
    metadata_only: list[dict[str, Any]] = []
    resource_to_hashes: dict[str, set[str]] = defaultdict(set)
    summaries: list[dict[str, Any]] = []

    for archive_label, root in ARCHIVES:
        object_files = sorted((root / "objects").glob("*")) if root.exists() else []
        for object_path in object_files:
            if not object_path.is_file():
                continue
            digest = add_payload_path(object_path, payload_paths, payload_sizes)
            if object_path.stem != digest:
                raise ValueError(
                    f"archive object name/hash mismatch: {relative_path(object_path)}"
                )

        current_count = 0
        history_count = 0
        for manifest_path, is_current in archive_manifests(root):
            current_count += int(is_current)
            history_count += int(not is_current)
            capture = read_json(manifest_path)
            status = capture.get("captureStatus")
            local_path = capture.get("localPath")
            if status == "quarantined" or (
                isinstance(local_path, str) and has_quarantine_component(local_path)
            ):
                continue
            origin = relative_path(manifest_path)
            priority = 65 if is_current else 55
            digest = capture.get("sha256")
            resource_id = capture.get("resourceID")
            if isinstance(digest, str) and digest:
                if status not in {"accepted", "duplicate"}:
                    continue
                if not isinstance(local_path, str) or not local_path:
                    raise ValueError(f"accepted manifest omitted localPath: {origin}")
                object_path = root / local_path
                if not object_path.is_file():
                    raise ValueError(f"accepted manifest object missing: {origin}")
                actual = add_payload_path(object_path, payload_paths, payload_sizes)
                if actual != digest:
                    raise ValueError(f"accepted manifest hash mismatch: {origin}")
                facts_by_sha[digest].append(
                    normalize_capture(capture, archive_label, origin, priority)
                )
                if isinstance(resource_id, str) and resource_id:
                    resource_to_hashes[resource_id].add(digest)
            elif is_current and status in {"linkOnly", "gitPinned"}:
                fact = normalize_capture(
                    capture, archive_label, origin, priority
                )
                metadata_only.append(
                    {
                        "resource_id": resource_id,
                        "record_type": (
                            "git" if status == "gitPinned" else "link"
                        ),
                        "facts": [fact],
                    }
                )

        summaries.append(
            {
                "path": relative_path(root),
                "exists": root.exists(),
                "object_count": len([path for path in object_files if path.is_file()]),
                "current_manifest_count": current_count,
                "history_manifest_count": history_count,
            }
        )
    return metadata_only, resource_to_hashes, summaries


def load_rich_declarations() -> tuple[
    dict[str, list[dict[str, Any]]],
    dict[str, list[dict[str, Any]]],
    list[str],
]:
    by_resource: dict[str, list[dict[str, Any]]] = defaultdict(list)
    by_sha: dict[str, list[dict[str, Any]]] = defaultdict(list)
    input_paths: list[str] = []

    declaration_paths = sorted(
        set((RESEARCH_ROOT / "manifests").glob("**/*.jsonl"))
        | set((RESEARCH_ROOT / "metadata").glob("source-manifest*.jsonl"))
    )
    for path in declaration_paths:
        input_paths.append(relative_path(path))
        for source in read_jsonl(path):
            resource_id = source.get("resource_id") or source.get("resourceID")
            fact = normalize_source_declaration(
                source, f"{relative_path(path)}#resource:{resource_id}", 100
            )
            if isinstance(resource_id, str) and resource_id:
                by_resource[resource_id].append(fact)
            digest = source.get("sha256")
            if isinstance(digest, str) and digest:
                by_sha[digest].append(fact)

    results_path = RESEARCH_ROOT / "metadata" / "ingestion-results.jsonl"
    if results_path.is_file():
        input_paths.append(relative_path(results_path))
        for index, result in enumerate(read_jsonl(results_path), start=1):
            source = result.get("source")
            if not isinstance(source, dict):
                continue
            resource_id = source.get("resource_id")
            fact = normalize_source_declaration(
                source, f"{relative_path(results_path)}#line:{index}", 105
            )
            if isinstance(resource_id, str) and resource_id:
                by_resource[resource_id].append(fact)
            capture = result.get("capture_record")
            if result.get("success") is True and isinstance(capture, dict):
                digest = capture.get("sha256")
                if isinstance(digest, str) and digest:
                    by_sha[digest].append(fact)
                    by_sha[digest].append(
                        normalize_capture(
                            capture,
                            "general",
                            f"{relative_path(results_path)}#capture:{index}",
                            70,
                        )
                    )
    return by_resource, by_sha, input_paths


def load_deep_review_facts() -> tuple[
    dict[str, list[dict[str, Any]]],
    dict[str, list[dict[str, Any]]],
    list[str],
]:
    """Project explicit deep-reading records into source-ledger facts.

    Review metadata is mutable analysis provenance, not an archive transport
    manifest. It may therefore refine review depth, evidence scope, and the
    reliability assessment, but it never supplies or changes payload paths.
    """

    by_resource: dict[str, list[dict[str, Any]]] = defaultdict(list)
    by_sha: dict[str, list[dict[str, Any]]] = defaultdict(list)
    input_paths: list[str] = []

    for path in sorted(
        (RESEARCH_ROOT / "metadata").glob("deep-review-*.jsonl")
    ):
        input_paths.append(relative_path(path))
        for index, review in enumerate(read_jsonl(path), start=1):
            resource_id = review.get("resource_id")
            digest = review.get("sha256") or review.get("payload_sha256")
            review_id = review.get("review_id") or f"line-{index}"
            confidence = review.get("confidence")
            if not confidence:
                scope = review.get("evidence_scope")
                confidence = (
                    f"deep review completed within stated scope: {scope}"
                    if useful(scope)
                    else "deep review completed within the recorded scope and limitations"
                )
            reference_class = review.get("reference_problem_class")
            topics = [reference_class] if useful(reference_class) else []
            fact = normalize_source_declaration(
                {
                    "resource_id": resource_id,
                    "title": review.get("title"),
                    "authors_or_inventors": review.get("creators"),
                    "publication_or_priority_date": review.get(
                        "publication_or_priority_date"
                    ),
                    "source_class": review.get("source_class", "unknown"),
                    "evidence_class": review.get("evidence_class", "unknown"),
                    "evidence_role": review.get("evidence_scope"),
                    "canonical_url": review.get("canonical_url"),
                    "retrieved_at_utc": review.get("retrieved_at_utc"),
                    "source_version": review.get("source_version"),
                    "accessibility_status": review.get("accessibility_status"),
                    "rights_status": review.get("rights_status"),
                    "review_depth": review.get("review_depth"),
                    "reliability_assessment": confidence,
                    "topics": topics,
                    "sha256": digest,
                },
                f"{relative_path(path)}#review:{review_id}",
                110,
            )
            if isinstance(resource_id, str) and resource_id:
                by_resource[resource_id].append(fact)
            if isinstance(digest, str) and re.fullmatch(r"[0-9a-f]{64}", digest):
                by_sha[digest].append(fact)

    return by_resource, by_sha, input_paths


def load_logic_request_facts() -> dict[str, list[dict[str, Any]]]:
    result: dict[str, list[dict[str, Any]]] = defaultdict(list)
    atlas_by_resource = {
        "apple-logic-pro-12.3-effects-guide-current": RESEARCH_ROOT
        / "analysis"
        / "TRACKSMITH_LOGIC_PRO_12_3_TOOL_ATLAS.md",
        "apple-logic-pro-12.3-instruments-guide-current": RESEARCH_ROOT
        / "analysis"
        / "TRACKSMITH_LOGIC_PRO_12_3_INSTRUMENT_ATLAS.md",
        "apple-logic-pro-12.3-user-guide-current": RESEARCH_ROOT
        / "analysis"
        / "TRACKSMITH_LOGIC_PRO_12_3_WORKFLOW_ATLAS.md",
        "apple-logic-pro-12.3-control-surfaces-guide-current": RESEARCH_ROOT
        / "analysis"
        / "TRACKSMITH_LOGIC_PRO_CONTROL_SURFACES_ATLAS.md",
    }
    for path in sorted((RESEARCH_ROOT / "manifests" / "logic-12.3").glob("*.json")):
        request = read_json(path)
        resource_id = request.get("resourceID")
        if not isinstance(resource_id, str):
            continue
        fact = normalize_source_declaration(
            {
                **request,
                "source_class": "official_manual",
                "evidence_class": "official documented product behavior",
                "review_depth": (
                    "full_document_review"
                    if atlas_by_resource.get(resource_id, Path("/missing")).is_file()
                    else "unknown"
                ),
                "reliability_assessment": "high_official_primary_source",
                "topics": ["logic_pro", "official_manual"],
            },
            relative_path(path),
            85,
        )
        result[resource_id].append(fact)
    return result


def producer_review_depths() -> dict[str, str]:
    path = RESEARCH_ROOT / "analysis" / "TRACKSMITH_PRODUCER_JUDGMENT_EXPANSION.md"
    result: dict[str, str] = {}
    if not path.is_file():
        return result
    for line in path.read_text(encoding="utf-8").splitlines():
        match = re.search(
            r"`([0-9a-f]{64})`\s*\|\s*"
            r"(Core|Supporting|Full source read|Full relevant read|"
            r"Full relevant source read, including appendices/prompts|"
            r"Initial supporting read)\s*\|",
            line,
        )
        if match:
            label = match.group(2)
            if label.startswith("Full"):
                label = "full_source_read"
            elif label.startswith("Initial supporting"):
                label = "supporting"
            result[match.group(1)] = normalized_review_depth(label)
    return result


def load_producer_facts() -> dict[str, list[dict[str, Any]]]:
    result: dict[str, list[dict[str, Any]]] = defaultdict(list)
    results_path = (
        REPO_ROOT
        / "TrackSmith_Producer_Judgment_Expansion"
        / "04_manifest"
        / "ingestion_results.json"
    )
    source_manifest = results_path.with_name("source_manifest.csv")
    if not results_path.is_file():
        return result

    rows_by_url: dict[str, dict[str, str]] = {}
    if source_manifest.is_file():
        with source_manifest.open(newline="", encoding="utf-8-sig") as handle:
            for row in csv.DictReader(handle):
                rows_by_url[row["url"]] = row
    reviews = producer_review_depths()
    resources = read_json(results_path).get("resources", [])
    for index, resource in enumerate(resources, start=1):
        if not isinstance(resource, dict):
            continue
        digest = resource.get("sha256")
        if not isinstance(digest, str):
            continue
        row = rows_by_url.get(str(resource.get("canonical_url")), {})
        fact = normalize_source_declaration(
            {
                "resource_id": resource.get("resource_id"),
                "title": resource.get("title"),
                "authors_or_inventors": split_people(resource.get("authors")),
                "publisher_or_authors": resource.get("authors"),
                "publication_or_priority_date": row.get("year") or None,
                "source_class": "academic_paper",
                "evidence_class": "unknown",
                "evidence_role": row.get("key_value"),
                "canonical_url": resource.get("canonical_url"),
                "retrieval_url": resource.get("retrieval_url"),
                "retrieved_at_utc": resource.get("retrieved_at_utc"),
                "source_version": resource.get("source_version"),
                "accessibility_status": "retrieved",
                "handling_class": resource.get("handling_class"),
                "local_use_only": resource.get("local_use_only"),
                "review_depth": reviews.get(digest, "unknown"),
                "reliability_assessment": "unknown",
                "tracksmith_relevance": row.get("key_value") or None,
                "topics": [row["category"]] if row.get("category") else [],
                "capture_status": resource.get("capture_status"),
                "quality_status": resource.get("quality_status"),
                "quality_findings": resource.get("quality_findings", []),
            },
            f"{relative_path(results_path)}#resource:{index}",
            90,
        )
        result[digest].append(fact)
    return result


def source_audit_rows() -> dict[int, tuple[str, str]]:
    path = RESEARCH_ROOT / "analysis" / "SOURCE_AUDIT.md"
    result: dict[int, tuple[str, str]] = {}
    if not path.is_file():
        return result
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.startswith("|"):
            continue
        parts = [part.strip() for part in line.strip().strip("|").split("|")]
        if len(parts) == 4 and re.fullmatch(r"\d{3}", parts[0]):
            result[int(parts[0])] = (
                normalized_review_depth(parts[2]),
                parts[3],
            )
    return result


def tta_part_name(number: int) -> str:
    for part, (start, end) in enumerate(TTA_PART_RANGES, start=1):
        if start <= number <= end:
            return f"TTA-Bench-sources-part-{part:02d}-items-{start:03d}-to-{end:03d}"
    raise ValueError(f"TTA source number is outside the manifest: {number}")


def load_legacy_tta_facts(
    payload_paths: dict[str, set[str]],
    payload_sizes: dict[str, int],
) -> tuple[dict[str, list[dict[str, Any]]], list[dict[str, Any]]]:
    result: dict[str, list[dict[str, Any]]] = defaultdict(list)
    unavailable_records: list[dict[str, Any]] = []
    source_index = (
        RESEARCH_ROOT
        / "extracted"
        / "TTA-Bench-sources-part-01-items-001-to-015"
        / "source_index.csv"
    )
    if not source_index.is_file():
        return result, unavailable_records
    reviews = source_audit_rows()
    with source_index.open(newline="", encoding="utf-8-sig") as handle:
        rows = list(csv.DictReader(handle))
    for row in rows:
        number = int(row["number"])
        path = (
            RESEARCH_ROOT
            / "extracted"
            / tta_part_name(number)
            / "sources"
            / row["file"]
        )
        review_depth, disposition = reviews.get(number, ("unknown", ""))
        source_format = row.get("format", "").upper()
        source_class = {
            "PDF": "legacy_document",
            "HTML": "web_page",
            "TXT": "text_source",
        }.get(source_format, "unknown")
        accessibility = "retrieved" if path.stat().st_size > 0 else "unavailable"
        placeholder_sha256 = sha256_file(path) if path.stat().st_size == 0 else None
        fact = make_fact(
            45,
            f"{relative_path(source_index)}#slot:{number:03d}",
            title=row.get("title") or None,
            authors_or_inventors=[],
            organization_or_assignee=None,
            publisher_or_authors_raw=None,
            publication_or_priority_date=None,
            source_class=source_class,
            evidence_class="unknown",
            evidence_role=None,
            canonical_url=row.get("original_url") or None,
            retrieval_url=row.get("retrieved_url") or None,
            retrieved_at_utc=None,
            document_version=None,
            patent_family_id=None,
            work_family_id=None,
            accessibility_status=accessibility,
            rights_status="unknown",
            rights_basis=None,
            handling_class="unknown",
            license_status="unknown",
            license_spdx=None,
            local_use_only=None,
            review_depth=review_depth,
            reliability_assessment="unknown",
            tracksmith_relevance=disposition or None,
            relevance_notes=[disposition] if disposition else [],
            topics=[],
            resource_ids=[f"tta-source-{number:03d}"],
            capture_mode=source_format.lower() if source_format else "unknown",
            media_type=media_type_for(path),
            capture_status="legacy-supplied",
            quality_status=("unavailable" if path.stat().st_size == 0 else "legacy-audited"),
            quality_findings=[],
            git_commit=None,
            git_remote_url=None,
            placeholder_sha256=placeholder_sha256,
            placeholder_paths=(
                [relative_path(path)] if path.stat().st_size == 0 else []
            ),
            supersedes_sha256=None,
        )
        if path.stat().st_size == 0:
            fact["quality_findings"] = [
                "Zero-byte placeholder retained for citation recovery; no usable source payload is available."
            ]
            unavailable_records.append(
                {
                    "resource_id": f"tta-source-{number:03d}",
                    "record_type": "unavailable",
                    "facts": [fact],
                }
            )
        else:
            digest = add_payload_path(path, payload_paths, payload_sizes)
            result[digest].append(fact)
    return result, unavailable_records


def parse_papers_readme() -> dict[int, tuple[str, str]]:
    path = RESEARCH_ROOT / "papers" / "README.md"
    result: dict[int, tuple[str, str]] = {}
    if not path.is_file():
        return result
    pattern = re.compile(
        r"^\s*(\d+)\.\s+\*\*(.+?)\*\*\s+—\s+\[[^\]]+\]\(([^)]+)\)"
    )
    for line in path.read_text(encoding="utf-8").splitlines():
        match = pattern.match(line)
        if match:
            result[int(match.group(1))] = (match.group(2), match.group(3))
    return result


def load_curated_paper_facts(
    payload_paths: dict[str, set[str]],
    payload_sizes: dict[str, int],
) -> dict[str, list[dict[str, Any]]]:
    result: dict[str, list[dict[str, Any]]] = defaultdict(list)
    readme_entries = parse_papers_readme()
    for path in sorted((RESEARCH_ROOT / "papers").glob("[0-9][0-9]_*.pdf")):
        number = int(path.name[:2])
        digest = add_payload_path(path, payload_paths, payload_sizes)
        title, canonical_url = readme_entries.get(number, (None, None))
        is_standard = number in {13, 14, 15}
        fact = make_fact(
            50,
            f"{relative_path(RESEARCH_ROOT / 'papers' / 'README.md')}#item:{number}",
            title=title,
            authors_or_inventors=[],
            organization_or_assignee=None,
            publisher_or_authors_raw=None,
            publication_or_priority_date=None,
            source_class=("normative_standard" if is_standard else "academic_paper"),
            evidence_class=("normative standard" if is_standard else "unknown"),
            evidence_role=None,
            canonical_url=canonical_url,
            retrieval_url=canonical_url,
            retrieved_at_utc=None,
            document_version=None,
            patent_family_id=None,
            work_family_id=None,
            accessibility_status="retrieved",
            rights_status="unknown",
            rights_basis=None,
            handling_class="unknown",
            license_status="unknown",
            license_spdx=None,
            local_use_only=None,
            review_depth="core",
            reliability_assessment=(
                "high_normative_primary_source" if is_standard else "unknown"
            ),
            tracksmith_relevance=None,
            relevance_notes=[],
            topics=[],
            resource_ids=[f"curated-production-source-{number:02d}"],
            capture_mode="pdf",
            media_type="application/pdf",
            capture_status="legacy-supplied",
            quality_status="legacy-audited",
            quality_findings=[],
            git_commit=None,
            git_remote_url=None,
            supersedes_sha256=None,
        )
        result[digest].append(fact)

    wimp = RESEARCH_ROOT / "papers" / "WIMP2017_Martinez-RamirezReiss.pdf"
    if wimp.is_file():
        digest = add_payload_path(wimp, payload_paths, payload_sizes)
        result[digest].append(
            make_fact(
                50,
                "research/analysis/SOURCE_AUDIT.md#wimp-2017",
                title="Deep Learning and Intelligent Audio Mixing",
                authors_or_inventors=[],
                organization_or_assignee=None,
                publisher_or_authors_raw=None,
                publication_or_priority_date="2017",
                source_class="academic_paper",
                evidence_class="unknown",
                evidence_role=None,
                canonical_url=None,
                retrieval_url=None,
                retrieved_at_utc=None,
                document_version=None,
                patent_family_id=None,
                work_family_id=None,
                accessibility_status="retrieved",
                rights_status="unknown",
                rights_basis=None,
                handling_class="unknown",
                license_status="unknown",
                license_spdx=None,
                local_use_only=None,
                review_depth="core",
                reliability_assessment="unknown",
                tracksmith_relevance=(
                    "Expert mixes, production domain knowledge, and creative goals "
                    "remain necessary beyond clean automation."
                ),
                relevance_notes=[],
                topics=[],
                resource_ids=["wimp-2017-intelligent-audio-mixing"],
                capture_mode="pdf",
                media_type="application/pdf",
                capture_status="legacy-supplied",
                quality_status="legacy-audited",
                quality_findings=[],
                git_commit=None,
                git_remote_url=None,
                supersedes_sha256=None,
            )
        )
    return result


def discover_source_files(
    payload_paths: dict[str, set[str]],
    payload_sizes: dict[str, int],
) -> None:
    candidates: set[Path] = set()
    candidates.update((RESEARCH_ROOT / "papers").glob("*.pdf"))
    candidates.update((RESEARCH_ROOT / "papers").glob("TTA-Bench-*/sources/*"))
    candidates.update((RESEARCH_ROOT / "extracted").glob("*/sources/*"))
    candidates.update(
        (
            RESEARCH_ROOT
            / "extracted"
            / "Audio_Production_Papers_and_Standards"
            / "audio-production-papers"
        ).glob("*.pdf")
    )
    expansion = REPO_ROOT / "TrackSmith_Producer_Judgment_Expansion"
    if expansion.is_dir():
        candidates.update(expansion.glob("**/*.pdf"))

    for source_root in (
        RESEARCH_ROOT / "standards",
        RESEARCH_ROOT / "datasets",
        RESEARCH_ROOT / "code-and-supplements",
    ):
        if source_root.is_dir():
            candidates.update(path for path in source_root.rglob("*") if path.is_file())

    library = RESEARCH_ROOT / "library"
    if library.is_dir():
        archive_roots = [root for _, root in ARCHIVES]
        for path in library.rglob("*"):
            if not path.is_file() or any(
                is_relative_to(path, archive_root) for archive_root in archive_roots
            ):
                continue
            candidates.add(path)

    for path in sorted(candidates):
        if not path.is_file() or path.name.startswith("."):
            continue
        if has_quarantine_component(path):
            continue
        if path.stat().st_size == 0:
            continue
        add_payload_path(path, payload_paths, payload_sizes)


def attach_resource_facts(
    facts_by_sha: dict[str, list[dict[str, Any]]],
    resource_to_hashes: dict[str, set[str]],
    rich_by_resource: dict[str, list[dict[str, Any]]],
) -> None:
    for resource_id in sorted(resource_to_hashes):
        for digest in sorted(resource_to_hashes[resource_id]):
            facts_by_sha[digest].extend(rich_by_resource.get(resource_id, []))


def make_payload_records(
    payload_paths: dict[str, set[str]],
    payload_sizes: dict[str, int],
    facts_by_sha: dict[str, list[dict[str, Any]]],
) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for digest in sorted(payload_paths):
        paths = sorted(payload_paths[digest], key=path_preference)
        if not paths:
            raise ValueError(f"payload {digest} has no source paths")
        if any(has_quarantine_component(path) for path in paths):
            raise ValueError(f"quarantine leaked into payload {digest}")
        merged = merge_facts(facts_by_sha.get(digest, []))
        primary_path = paths[0]
        primary_media_type = media_type_for(REPO_ROOT / primary_path)
        if merged["media_type"] in {None, "unknown"}:
            merged["media_type"] = primary_media_type
        if merged["capture_mode"] in {None, "unknown"}:
            merged["capture_mode"] = {
                "application/pdf": "pdf",
                "text/html": "html",
                "text/plain": "text",
            }.get(primary_media_type, "binary")
        if merged["accessibility_status"] == "unknown":
            merged["accessibility_status"] = (
                "unavailable" if payload_sizes[digest] == 0 else "retrieved"
            )
        if merged["capture_status"] == "unknown":
            merged["capture_status"] = "legacy-supplied"

        supersedes = merged.pop("supersedes_sha256")
        record = {
            "schema_version": SCHEMA_VERSION,
            "record_type": "payload",
            "source_id": f"payload-sha256:{digest}",
            **merged,
            "local_path": primary_path,
            "duplicate_paths": paths[1:],
            "all_local_paths": paths,
            "sha256": digest,
            "byte_count": payload_sizes[digest],
            "supersedes_source_ids": (
                [f"payload-sha256:{supersedes}"]
                if isinstance(supersedes, str) and supersedes
                else []
            ),
            "superseded_by_source_ids": [],
            "duplicate_of_source_id": None,
            "duplicate_relationship_status": (
                "byte-identical paths consolidated; intellectual work family unresolved"
            ),
        }
        records.append(record)

    by_id = {record["source_id"]: record for record in records}
    for record in records:
        for prior in record["supersedes_source_ids"]:
            if prior in by_id:
                by_id[prior]["superseded_by_source_ids"].append(record["source_id"])
    for record in records:
        record["superseded_by_source_ids"].sort()
    return records


def make_metadata_records(
    metadata_only: list[dict[str, Any]],
    rich_by_resource: dict[str, list[dict[str, Any]]],
) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    seen: set[str] = set()
    for item in metadata_only:
        resource_id = item["resource_id"]
        if not isinstance(resource_id, str) or not resource_id:
            raise ValueError("metadata-only record omitted resourceID")
        source_id = f"resource:{resource_id}"
        if source_id in seen:
            raise ValueError(f"duplicate metadata-only source ID: {source_id}")
        seen.add(source_id)
        facts = list(item["facts"]) + rich_by_resource.get(resource_id, [])
        merged = merge_facts(facts)
        merged.pop("supersedes_sha256")
        records.append(
            {
                "schema_version": SCHEMA_VERSION,
                "record_type": item["record_type"],
                "source_id": source_id,
                **merged,
                "local_path": None,
                "duplicate_paths": [],
                "all_local_paths": [],
                "sha256": None,
                "byte_count": None,
                "supersedes_source_ids": [],
                "superseded_by_source_ids": [],
                "duplicate_of_source_id": None,
                "duplicate_relationship_status": (
                    "not-applicable-unavailable-source-payload"
                    if item["record_type"] == "unavailable"
                    else "not-applicable-metadata-only"
                ),
            }
        )
    return records


def validate_records(records: list[dict[str, Any]]) -> None:
    required = {
        "schema_version",
        "record_type",
        "source_id",
        "title",
        "authors_or_inventors",
        "organization_or_assignee",
        "publication_or_priority_date",
        "source_class",
        "evidence_class",
        "canonical_url",
        "local_path",
        "duplicate_paths",
        "sha256",
        "retrieved_at_utc",
        "document_version",
        "patent_family_id",
        "work_family_id",
        "accessibility_status",
        "rights_status",
        "review_depth",
        "reliability_assessment",
        "tracksmith_relevance",
        "topics",
        "supersedes_source_ids",
        "superseded_by_source_ids",
    }
    source_ids: set[str] = set()
    payload_hashes: set[str] = set()
    for record in records:
        missing = sorted(required - set(record))
        if missing:
            raise ValueError(f"{record.get('source_id')}: missing fields {missing}")
        source_id = record["source_id"]
        if source_id in source_ids:
            raise ValueError(f"duplicate source_id: {source_id}")
        source_ids.add(source_id)
        for path in record["all_local_paths"]:
            if has_quarantine_component(path):
                raise ValueError(f"quarantine path in source index: {path}")
        for path in record["placeholder_paths"]:
            if has_quarantine_component(path):
                raise ValueError(f"quarantine placeholder in source index: {path}")
        if record["record_type"] == "payload":
            digest = record["sha256"]
            if digest in payload_hashes:
                raise ValueError(f"duplicate payload record: {digest}")
            payload_hashes.add(digest)
            local_path = REPO_ROOT / record["local_path"]
            if sha256_file(local_path) != digest:
                raise ValueError(f"indexed payload changed: {record['local_path']}")
        elif record["sha256"] is not None or record["local_path"] is not None:
            raise ValueError(f"metadata-only record retained payload fields: {source_id}")
        if record["record_type"] == "unavailable":
            if not record["placeholder_paths"] or not record["placeholder_sha256"]:
                raise ValueError(f"unavailable record omitted placeholder provenance: {source_id}")
            for path in record["placeholder_paths"]:
                placeholder = REPO_ROOT / path
                if placeholder.stat().st_size != 0:
                    raise ValueError(f"unavailable placeholder became nonempty: {path}")
                if sha256_file(placeholder) != record["placeholder_sha256"]:
                    raise ValueError(f"unavailable placeholder hash changed: {path}")


def bibliography_entry(record: dict[str, Any]) -> dict[str, Any]:
    return {
        "source_id": record["source_id"],
        "resource_ids": record["resource_ids"],
        "title": record["title"],
        "alternate_titles": record["alternate_titles"],
        "authors_or_inventors": record["authors_or_inventors"],
        "organization_or_assignee": record["organization_or_assignee"],
        "publication_or_priority_date": record["publication_or_priority_date"],
        "publication_date": record["publication_date"],
        "priority_date": record["priority_date"],
        "source_class": record["source_class"],
        "evidence_class": record["evidence_class"],
        "canonical_url": record["canonical_url"],
        "retrieval_url": record["retrieval_url"],
        "document_version": record["document_version"],
        "patent_family_id": record["patent_family_id"],
        "work_family_id": record["work_family_id"],
        "accessibility_status": record["accessibility_status"],
        "rights_status": record["rights_status"],
        "review_depth": record["review_depth"],
        "reliability_assessment": record["reliability_assessment"],
        "tracksmith_relevance": record["tracksmith_relevance"],
        "topics": record["topics"],
        "payload": (
            {
                "sha256": record["sha256"],
                "byte_count": record["byte_count"],
                "media_type": record["media_type"],
                "local_path": record["local_path"],
                "duplicate_paths": record["duplicate_paths"],
            }
            if record["record_type"] == "payload"
            else None
        ),
        "git_commit": record["git_commit"],
        "git_remote_url": record["git_remote_url"],
        "unavailable_placeholder": (
            {
                "sha256": record["placeholder_sha256"],
                "paths": record["placeholder_paths"],
            }
            if record["record_type"] == "unavailable"
            else None
        ),
        "supersedes_source_ids": record["supersedes_source_ids"],
        "superseded_by_source_ids": record["superseded_by_source_ids"],
    }


def build_bibliography(
    records: list[dict[str, Any]],
    source_index_text: str,
    archive_summaries: list[dict[str, Any]],
    manifest_inputs: list[str],
    quarantine_file_count: int,
    archive_container_count: int,
) -> dict[str, Any]:
    record_types = Counter(record["record_type"] for record in records)
    source_classes = Counter(record["source_class"] for record in records)
    review_depths = Counter(record["review_depth"] for record in records)
    media_types = Counter(
        record["media_type"]
        for record in records
        if record["record_type"] == "payload"
    )
    unknown_fields = (
        "title",
        "publication_or_priority_date",
        "publication_date",
        "priority_date",
        "source_class",
        "evidence_class",
        "canonical_url",
        "document_version",
        "patent_family_id",
        "work_family_id",
        "rights_status",
        "review_depth",
        "reliability_assessment",
        "tracksmith_relevance",
    )
    unknown_counts = {
        field: sum(
            1 for record in records if record.get(field) in {None, "unknown"}
        )
        for field in unknown_fields
    }
    unknown_counts["topics"] = sum(1 for record in records if not record["topics"])
    unknown_counts["authors_or_inventors"] = sum(
        1 for record in records if record["authors_or_inventors"] is None
    )

    return {
        "schema_version": "tracksmith.bibliography.v1",
        "source_index_schema_version": SCHEMA_VERSION,
        "product": "TrackSmith",
        "generation": {
            "generated_by": "research/scripts/build-source-index.py",
            "generated_at_utc": None,
            "timestamp_policy": "omitted_for_byte_determinism",
            "deterministic": True,
            "source_index_path": relative_path(DEFAULT_SOURCE_INDEX),
            "source_index_sha256": sha256_text(source_index_text),
            "record_count": len(records),
            "payload_record_count": record_types.get("payload", 0),
            "metadata_only_record_count": len(records)
            - record_types.get("payload", 0),
            "unavailable_source_record_count": record_types.get("unavailable", 0),
            "record_type_counts": dict(sorted(record_types.items())),
            "media_type_counts": dict(sorted(media_types.items())),
            "source_class_counts": dict(sorted(source_classes.items())),
            "review_depth_counts": dict(sorted(review_depths.items())),
            "unknown_field_counts": unknown_counts,
            "archive_roots": archive_summaries,
            "source_manifest_inputs": sorted(manifest_inputs),
            "legacy_inputs": [
                "research/extracted/TTA-Bench-sources-part-01-items-001-to-015/source_index.csv",
                "research/analysis/SOURCE_AUDIT.md",
                "research/papers/README.md",
                "TrackSmith_Producer_Judgment_Expansion/04_manifest/source_manifest.csv",
                "TrackSmith_Producer_Judgment_Expansion/04_manifest/ingestion_results.json",
            ],
            "excluded_quarantine_file_count": quarantine_file_count,
            "excluded_archive_container_count": archive_container_count,
            "archive_container_policy": (
                "ZIP transport bundles are preserved in place but are not independent "
                "bibliographic source payloads; their source members are indexed."
            ),
            "zero_byte_placeholder_policy": (
                "Zero-byte legacy captures are separate unavailable metadata records, "
                "not source payloads and not intellectual-work duplicates."
            ),
        },
        "unknown_value_policy": {
            "unavailable_scalar_fact": None,
            "unavailable_authors_or_inventors": None,
            "unassessed_categorical_value": "unknown",
            "unassigned_topics": [],
            "work_family_placeholder": None,
            "patent_family_placeholder": None,
        },
        "entries": [bibliography_entry(record) for record in records],
    }


def atomic_write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.tmp")
    temporary.write_text(content, encoding="utf-8")
    temporary.replace(path)


def run() -> int:
    arguments = parse_arguments()
    source_index_path = arguments.source_index.resolve()
    bibliography_path = arguments.bibliography.resolve()
    if source_index_path != DEFAULT_SOURCE_INDEX.resolve() or bibliography_path != DEFAULT_BIBLIOGRAPHY.resolve():
        raise ValueError(
            "The baseline ledger has canonical output paths; alternate outputs are not supported."
        )

    payload_paths: dict[str, set[str]] = defaultdict(set)
    payload_sizes: dict[str, int] = {}
    facts_by_sha: dict[str, list[dict[str, Any]]] = defaultdict(list)

    rich_by_resource, rich_by_sha, manifest_inputs = load_rich_declarations()
    review_by_resource, review_by_sha, review_inputs = load_deep_review_facts()
    manifest_inputs.extend(review_inputs)
    for resource_id, facts in review_by_resource.items():
        rich_by_resource[resource_id].extend(facts)
    for digest, facts in review_by_sha.items():
        rich_by_sha[digest].extend(facts)
    logic_by_resource = load_logic_request_facts()
    for resource_id, facts in logic_by_resource.items():
        rich_by_resource[resource_id].extend(facts)

    metadata_only, resource_to_hashes, archive_summaries = discover_archives(
        payload_paths,
        payload_sizes,
        facts_by_sha,
    )
    for digest, facts in rich_by_sha.items():
        facts_by_sha[digest].extend(facts)
    for digest, facts in load_producer_facts().items():
        facts_by_sha[digest].extend(facts)
    legacy_facts, unavailable_records = load_legacy_tta_facts(
        payload_paths, payload_sizes
    )
    metadata_only.extend(unavailable_records)
    for digest, facts in legacy_facts.items():
        facts_by_sha[digest].extend(facts)
    for digest, facts in load_curated_paper_facts(
        payload_paths, payload_sizes
    ).items():
        facts_by_sha[digest].extend(facts)

    discover_source_files(payload_paths, payload_sizes)
    attach_resource_facts(facts_by_sha, resource_to_hashes, rich_by_resource)

    records = make_payload_records(payload_paths, payload_sizes, facts_by_sha)
    records.extend(make_metadata_records(metadata_only, rich_by_resource))
    records.sort(key=lambda record: record["source_id"])
    validate_records(records)

    source_index_text = "".join(
        json.dumps(record, sort_keys=True, ensure_ascii=False, separators=(",", ":"))
        + "\n"
        for record in records
    )
    quarantine_file_count = sum(
        1
        for _, root in ARCHIVES
        for path in (root / "quarantine").glob("*")
        if path.is_file()
    )
    archive_container_count = len(
        [path for path in (RESEARCH_ROOT / "papers").glob("*.zip") if path.is_file()]
    )
    bibliography = build_bibliography(
        records,
        source_index_text,
        archive_summaries,
        manifest_inputs,
        quarantine_file_count,
        archive_container_count,
    )
    bibliography_text = (
        json.dumps(bibliography, indent=2, sort_keys=True, ensure_ascii=False) + "\n"
    )

    atomic_write(source_index_path, source_index_text)
    atomic_write(bibliography_path, bibliography_text)

    # Parse the final bytes, not just in-memory structures.
    parsed_records = read_jsonl(source_index_path)
    parsed_bibliography = read_json(bibliography_path)
    if len(parsed_records) != len(records):
        raise ValueError("final SOURCE_INDEX record count changed during write")
    if parsed_bibliography["generation"]["source_index_sha256"] != sha256_file(
        source_index_path
    ):
        raise ValueError("BIBLIOGRAPHY source-index hash does not match final bytes")
    validate_records(parsed_records)

    print(
        f"wrote {len(records)} source records "
        f"({sum(record['record_type'] == 'payload' for record in records)} payload, "
        f"{sum(record['record_type'] != 'payload' for record in records)} metadata-only); "
        f"quarantine files excluded={quarantine_file_count}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(run())
