#!/usr/bin/env python3
"""Audit TrackSmith's local, rights-aware natural-audio evidence corpus."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import tarfile
import sys
import wave
import zipfile
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any


REQUIRED_DATASET_FIELDS = {
    "datasetID",
    "priority",
    "lane",
    "officialPage",
    "declaredVersion",
    "materialContribution",
    "datasetAnnotationClasses",
    "handlingClass",
    "rightsStatus",
    "localUseOnly",
    "audioAccess",
    "plannedScope",
    "status",
    "limitations",
}

REQUIRED_CAPTURE_FIELDS = {
    "captureID",
    "datasetID",
    "lane",
    "sourceURL",
    "retrievedAt",
    "sourceVersion",
    "handlingClass",
    "rightsStatus",
    "localUseOnly",
    "relativePath",
    "mediaType",
    "byteCount",
    "sha256",
    "validation",
    "evaluationRoles",
}

REQUIRED_ANNOTATION_FIELDS = {
    "annotationID",
    "datasetID",
    "assetID",
    "split",
    "timeScope",
    "datasetSupplied",
    "mechanicallyDerived",
    "directlyCurated",
    "productionJudgment",
    "listeningEvidence",
    "evaluationLinks",
}

HANDLING_CLASSES = {
    "redistributable",
    "internalReference",
    "linkAndNotes",
    "licenseReviewRequired",
}

REQUIRED_LANES = {
    "natural_multitrack_or_known_stem_audio",
    "audio_grounded_production_or_music_language",
}

DECLARED_SPLITS = {
    "train",
    "validation",
    "test",
    "evaluation",
    "tracksmith_holdout",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--require-ready",
        action="store_true",
        help="Exit nonzero unless every G1.5 exit condition is satisfied.",
    )
    parser.add_argument(
        "--write-report",
        type=Path,
        help="Write the deterministic JSON report to this repo-relative or absolute path.",
    )
    return parser.parse_args()


def load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def md5(path: Path) -> str:
    digest = hashlib.md5(usedforsecurity=False)
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def validate_capture_payload(
    repo_root: Path, payload_root: Path, capture: dict[str, Any]
) -> tuple[list[str], dict[str, Any]]:
    errors: list[str] = []
    details: dict[str, Any] = {}
    relative = Path(capture["relativePath"])
    path = repo_root / relative

    if not path.exists():
        return [f"missing capture payload: {relative}"], details
    if not path.is_file():
        return [f"capture payload is not a file: {relative}"], details
    try:
        path.resolve().relative_to(payload_root.resolve())
    except ValueError:
        errors.append(f"capture payload escapes local payload root: {relative}")

    actual_bytes = path.stat().st_size
    actual_sha = sha256(path)
    details.update({"byteCount": actual_bytes, "sha256": actual_sha})
    if actual_bytes != capture["byteCount"]:
        errors.append(
            f"{capture['captureID']}: byte count {actual_bytes} != {capture['byteCount']}"
        )
    if actual_sha != capture["sha256"]:
        errors.append(
            f"{capture['captureID']}: sha256 {actual_sha} != {capture['sha256']}"
        )

    media_type = capture["mediaType"]
    container_format = capture.get("validation", {}).get("containerFormat")
    expected_publisher_md5 = capture.get("validation", {}).get(
        "expectedPublisherMD5"
    )
    if expected_publisher_md5 is not None:
        actual_md5 = md5(path)
        details["md5"] = actual_md5
        if actual_md5 != expected_publisher_md5:
            errors.append(
                f"{capture['captureID']}: publisher MD5 {actual_md5} != "
                f"{expected_publisher_md5}"
            )
    try:
        if container_format == "parquet":
            with path.open("rb") as handle:
                header = handle.read(4)
                handle.seek(-8, 2)
                footer = handle.read(8)
            footer_length = int.from_bytes(footer[:4], "little")
            if header != b"PAR1" or footer[4:] != b"PAR1":
                errors.append(
                    f"{capture['captureID']}: parquet boundary magic is invalid"
                )
            elif footer_length <= 0 or footer_length + 8 > actual_bytes:
                errors.append(
                    f"{capture['captureID']}: parquet footer length is invalid"
                )
            details["parquetFooterByteCount"] = footer_length
            details["containerValidation"] = "parquet_magic_and_footer_passed"
        elif container_format == "tar_gzip":
            member_count = 0
            regular_file_count = 0
            uncompressed_bytes = 0
            with tarfile.open(path, "r:gz") as archive:
                for member in archive:
                    member_path = Path(member.name)
                    if member_path.is_absolute() or ".." in member_path.parts:
                        errors.append(
                            f"{capture['captureID']}: unsafe tar member {member.name}"
                        )
                    member_count += 1
                    if member.isfile():
                        regular_file_count += 1
                        uncompressed_bytes += member.size
            if regular_file_count == 0:
                errors.append(f"{capture['captureID']}: tar archive has no files")
            details.update(
                {
                    "archiveMemberCount": member_count,
                    "archiveRegularFileCount": regular_file_count,
                    "archiveUncompressedByteCount": uncompressed_bytes,
                    "containerValidation": "tar_gzip_integrity_passed",
                }
            )
        elif media_type in {"application/json", "application/ld+json"}:
            load_json(path)
            details["containerValidation"] = "json_parse_passed"
        elif media_type in {
            "text/csv",
            "text/tab-separated-values",
        } or container_format in {"csv", "tsv"}:
            delimiter = (
                "\t"
                if media_type == "text/tab-separated-values"
                or container_format == "tsv"
                else ","
            )
            with path.open("r", encoding="utf-8", newline="") as handle:
                rows = list(csv.reader(handle, delimiter=delimiter))
            if not rows:
                errors.append(f"{capture['captureID']}: structured text has no rows")
            header_row_count = capture.get("validation", {}).get(
                "headerRowCount", 0
            )
            data_row_count = len(rows) - header_row_count
            expected_data_rows = capture.get("validation", {}).get(
                "expectedDataRowCount"
            )
            if expected_data_rows is not None and data_row_count != expected_data_rows:
                errors.append(
                    f"{capture['captureID']}: structured data row count "
                    f"{data_row_count} != {expected_data_rows}"
                )
            details["rowCount"] = len(rows)
            details["headerRowCount"] = header_row_count
            details["dataRowCount"] = data_row_count
            details["containerValidation"] = "structured_text_parse_passed"
        elif media_type in {
            "application/zip",
            "application/x-zip-compressed",
        } or container_format == "zip":
            with zipfile.ZipFile(path) as archive:
                corrupt = archive.testzip()
                members = archive.infolist()
                for member in members:
                    member_path = Path(member.filename)
                    if member_path.is_absolute() or ".." in member_path.parts:
                        errors.append(
                            f"{capture['captureID']}: unsafe zip member {member.filename}"
                        )
                details["archiveMemberCount"] = len(members)
                details["archiveUncompressedByteCount"] = sum(
                    member.file_size for member in members
                )
            if corrupt is not None:
                errors.append(
                    f"{capture['captureID']}: corrupt zip member {corrupt}"
                )
            details["containerValidation"] = "zip_integrity_passed"
        elif media_type in {"audio/wav", "audio/x-wav"}:
            with wave.open(str(path), "rb") as audio:
                details.update(
                    {
                        "channels": audio.getnchannels(),
                        "sampleRate": audio.getframerate(),
                        "sampleWidthBytes": audio.getsampwidth(),
                        "frameCount": audio.getnframes(),
                        "durationSeconds": (
                            audio.getnframes() / audio.getframerate()
                            if audio.getframerate()
                            else 0
                        ),
                    }
                )
            details["containerValidation"] = "pcm_wave_parse_passed"
        elif media_type.startswith("text/") or container_format == "text":
            text = path.read_text(encoding="utf-8")
            if not text.strip():
                errors.append(f"{capture['captureID']}: text payload is empty")
            line_count = len(text.splitlines())
            expected_data_rows = capture.get("validation", {}).get(
                "expectedDataRowCount"
            )
            if expected_data_rows is not None and line_count != expected_data_rows:
                errors.append(
                    f"{capture['captureID']}: text line count {line_count} != "
                    f"{expected_data_rows}"
                )
            details["characterCount"] = len(text)
            details["lineCount"] = line_count
            details["containerValidation"] = "utf8_text_passed"
        else:
            details["containerValidation"] = "hash_and_size_only"
    except (
        csv.Error,
        json.JSONDecodeError,
        UnicodeDecodeError,
        wave.Error,
        zipfile.BadZipFile,
        tarfile.TarError,
        OSError,
    ) as error:
        errors.append(f"{capture['captureID']}: payload validation failed: {error}")

    return errors, details


def main() -> int:
    args = parse_args()
    repo_root = Path(__file__).resolve().parents[2]
    corpus_dir = (
        repo_root
        / "research/evaluation/production-mastery-v1/audio-evidence-corpus"
    )
    manifest = load_json(corpus_dir / "dataset-manifest.json")
    ledger = load_json(corpus_dir / "acquisition-ledger.json")
    index = load_json(corpus_dir / "natural-audio-index.json")
    annotation_schema = load_json(corpus_dir / "annotation-schema.json")
    annotations_record = load_json(corpus_dir / "tracksmith-annotations.json")
    payload_root = repo_root / manifest["payloadRoot"]

    errors: list[str] = []
    warnings: list[str] = []

    if manifest.get("schemaVersion") != "1.0":
        errors.append("dataset manifest schemaVersion must be 1.0")
    if manifest.get("claimBoundary", {}).get("trainingAuthorized") is not False:
        errors.append("trainingAuthorized must remain false")
    if manifest.get("claimBoundary", {}).get("providerUploadAuthorized") is not False:
        errors.append("providerUploadAuthorized must remain false")
    if manifest.get("payloadTrackedByGit") is not False:
        errors.append("natural-audio payloads must remain untracked local material")

    datasets = manifest.get("datasets", [])
    dataset_ids = [item.get("datasetID") for item in datasets]
    duplicate_dataset_ids = sorted(
        item for item, count in Counter(dataset_ids).items() if count > 1
    )
    if duplicate_dataset_ids:
        errors.append(f"duplicate dataset IDs: {duplicate_dataset_ids}")
    dataset_by_id = {item["datasetID"]: item for item in datasets if "datasetID" in item}

    for dataset in datasets:
        missing = sorted(REQUIRED_DATASET_FIELDS - set(dataset))
        if missing:
            errors.append(
                f"dataset {dataset.get('datasetID', '<unknown>')} missing fields: {missing}"
            )
            continue
        if dataset["handlingClass"] not in HANDLING_CLASSES:
            errors.append(
                f"dataset {dataset['datasetID']} has invalid handling class"
            )
        if dataset["localUseOnly"] is not True:
            errors.append(
                f"dataset {dataset['datasetID']} must remain local-use-only in G1.5"
            )
        if not dataset["materialContribution"]:
            errors.append(
                f"dataset {dataset['datasetID']} has no material contribution"
            )
        if not dataset["limitations"]:
            errors.append(f"dataset {dataset['datasetID']} has no limitations")

    captures = manifest.get("acceptedCaptures", [])
    capture_ids = [capture.get("captureID") for capture in captures]
    duplicate_capture_ids = sorted(
        item for item, count in Counter(capture_ids).items() if count > 1
    )
    if duplicate_capture_ids:
        errors.append(f"duplicate capture IDs: {duplicate_capture_ids}")

    capture_details: dict[str, Any] = {}
    accepted_lanes: set[str] = set()
    accepted_datasets: set[str] = set()
    for capture in captures:
        missing = sorted(REQUIRED_CAPTURE_FIELDS - set(capture))
        if missing:
            errors.append(
                f"capture {capture.get('captureID', '<unknown>')} missing fields: {missing}"
            )
            continue
        if capture["datasetID"] not in dataset_by_id:
            errors.append(
                f"capture {capture['captureID']} names unknown dataset {capture['datasetID']}"
            )
        if capture["handlingClass"] not in HANDLING_CLASSES:
            errors.append(
                f"capture {capture['captureID']} has invalid handling class"
            )
        if capture["localUseOnly"] is not True:
            errors.append(
                f"capture {capture['captureID']} must remain local-use-only"
            )
        if not capture["evaluationRoles"]:
            errors.append(
                f"capture {capture['captureID']} has no TrackSmith evaluation role"
            )
        payload_errors, details = validate_capture_payload(
            repo_root, payload_root, capture
        )
        errors.extend(payload_errors)
        capture_details[capture["captureID"]] = details
        if not payload_errors:
            accepted_lanes.add(capture["lane"])
            accepted_datasets.add(capture["datasetID"])

    assets = index.get("assets", [])
    asset_ids = [asset.get("assetID") for asset in assets]
    duplicate_asset_ids = sorted(
        item for item, count in Counter(asset_ids).items() if count > 1
    )
    if duplicate_asset_ids:
        errors.append(f"duplicate natural-audio asset IDs: {duplicate_asset_ids}")

    split_hashes: dict[str, set[str]] = defaultdict(set)
    split_leaks: list[dict[str, Any]] = []
    for asset in assets:
        for key in {
            "assetID",
            "datasetID",
            "split",
            "artifactSHA256",
            "sourceClass",
            "role",
            "evaluationRoles",
        }:
            if key not in asset:
                errors.append(
                    f"asset {asset.get('assetID', '<unknown>')} missing {key}"
                )
        digest = asset.get("artifactSHA256")
        split = asset.get("split")
        if asset.get("sourceSplitContaminated") is True and len(
            asset.get("sourceSplits", [])
        ) < 2:
            errors.append(
                f"asset {asset.get('assetID')} claims source split "
                "contamination without multiple source splits"
            )
        if digest and split in DECLARED_SPLITS:
            for other_split, hashes in split_hashes.items():
                if other_split != split and digest in hashes:
                    split_leaks.append(
                        {
                            "sha256": digest,
                            "splitA": other_split,
                            "splitB": split,
                        }
                    )
            split_hashes[split].add(digest)
    if split_leaks:
        errors.append(f"exact split leakage detected: {split_leaks}")
    if index.get("summary", {}).get("exactSplitLeakCount") != len(split_leaks):
        errors.append("natural-audio index exactSplitLeakCount is stale")

    annotations = annotations_record.get("annotations", [])
    annotation_ids = [annotation.get("annotationID") for annotation in annotations]
    duplicate_annotation_ids = sorted(
        item for item, count in Counter(annotation_ids).items() if count > 1
    )
    if duplicate_annotation_ids:
        errors.append(f"duplicate annotation IDs: {duplicate_annotation_ids}")
    schema_required = set(annotation_schema.get("required", []))
    if schema_required != REQUIRED_ANNOTATION_FIELDS:
        errors.append("annotation schema required fields drifted from the auditor")

    linked_annotations = 0
    for annotation in annotations:
        missing = sorted(REQUIRED_ANNOTATION_FIELDS - set(annotation))
        if missing:
            errors.append(
                f"annotation {annotation.get('annotationID', '<unknown>')} missing fields: {missing}"
            )
            continue
        time_scope = annotation["timeScope"]
        if time_scope["endSeconds"] <= time_scope["startSeconds"]:
            errors.append(
                f"annotation {annotation['annotationID']} has a nonpositive time scope"
            )
        links = annotation["evaluationLinks"]
        if any(links.get(key) for key in links):
            linked_annotations += 1
        else:
            errors.append(
                f"annotation {annotation['annotationID']} has no evaluation link"
            )
        listening = annotation["listeningEvidence"]
        if listening["status"] != "completed" and listening["resultIDs"]:
            errors.append(
                f"annotation {annotation['annotationID']} names listening results before completion"
            )

    ledger_attempts = ledger.get("attempts", [])
    ledger_capture_ids = {
        attempt.get("captureID")
        for attempt in ledger_attempts
        if attempt.get("status") == "accepted"
    }
    manifest_capture_ids = set(capture_ids)
    if ledger_capture_ids != manifest_capture_ids:
        errors.append(
            "accepted capture IDs disagree between manifest and acquisition ledger"
        )
    if ledger.get("acceptedArtifactCount") != len(manifest_capture_ids):
        errors.append("acquisition ledger acceptedArtifactCount is stale")

    missing_required_lanes = sorted(REQUIRED_LANES - accepted_lanes)
    gate_ready = (
        not errors
        and not missing_required_lanes
        and len(assets) > 0
        and len(annotations) > 0
        and linked_annotations == len(annotations)
    )
    if not captures:
        warnings.append("no dataset artifacts have been accepted yet")
    if not assets:
        warnings.append("natural-audio index is empty")
    if not annotations:
        warnings.append("TrackSmith annotation overlay is empty")
    if missing_required_lanes:
        warnings.append(
            f"required accepted lanes still missing: {missing_required_lanes}"
        )

    report = {
        "schemaVersion": "1.0",
        "corpusID": manifest["corpusID"],
        "structuralAuditPassed": not errors,
        "gateReady": gate_ready,
        "datasetCount": len(datasets),
        "acceptedCaptureCount": len(captures),
        "acceptedDatasetIDs": sorted(accepted_datasets),
        "acceptedLanes": sorted(accepted_lanes),
        "missingRequiredLanes": missing_required_lanes,
        "indexedAssetCount": len(assets),
        "annotationCount": len(annotations),
        "linkedAnnotationCount": linked_annotations,
        "exactSplitLeakCount": len(split_leaks),
        "captureDetails": capture_details,
        "errors": errors,
        "warnings": warnings,
    }

    rendered = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.write_report:
        target = args.write_report
        if not target.is_absolute():
            target = repo_root / target
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(rendered, encoding="utf-8")
    sys.stdout.write(rendered)

    if errors:
        return 1
    if args.require_ready and not gate_ready:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
