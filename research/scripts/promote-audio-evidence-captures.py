#!/usr/bin/env python3
"""Promote reviewed local capture records into TrackSmith's checked-in corpus ledger."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


CORPUS_DIR = (
    "research/evaluation/production-mastery-v1/audio-evidence-corpus"
)
RETRY_REASON = (
    "The first Zenodo response exposed two identical Content-Type header values. "
    "The strict ingestor rejected the combined representation. After a regression-"
    "tested normalization change that accepts only repeated identical values and "
    "still rejects conflicts, the payload was reacquired and revalidated."
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    return parser.parse_args()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def digest(path: Path, algorithm: str) -> str:
    hasher = hashlib.new(algorithm)
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            hasher.update(block)
    return hasher.hexdigest()


def write_json(path: Path, value: Any) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(
        json.dumps(value, indent=2, sort_keys=False) + "\n", encoding="utf-8"
    )
    temporary.replace(path)


def main() -> int:
    args = parse_args()
    repo_root = Path(__file__).resolve().parents[2]
    corpus_dir = repo_root / CORPUS_DIR
    plan = load_json(corpus_dir / "acquisition-plan.json")
    manifest_path = corpus_dir / "dataset-manifest.json"
    ledger_path = corpus_dir / "acquisition-ledger.json"
    manifest = load_json(manifest_path)
    ledger = load_json(ledger_path)
    local_root = repo_root / plan["localRoot"]
    record_root = local_root / "capture-records"
    failure_root = local_root / "failed-attempts"

    captures: list[dict[str, Any]] = []
    attempts: list[dict[str, Any]] = []
    rejected_count = 0

    for artifact in plan["artifacts"]:
        if not artifact.get("enabled", True):
            continue
        capture_id = artifact["captureID"]
        record_path = record_root / f"{capture_id}.json"
        if not record_path.exists():
            raise RuntimeError(f"{capture_id}: no retained capture record")
        record = load_json(record_path)
        if record["captureStatus"] not in {"accepted", "duplicate"}:
            raise RuntimeError(
                f"{capture_id}: inadmissible capture status "
                f"{record['captureStatus']}"
            )
        if record["qualityStatus"] != "validated":
            raise RuntimeError(
                f"{capture_id}: capture quality was not validated"
            )

        payload_path = local_root / "archive" / record["localPath"]
        if payload_path.stat().st_size != record["byteCount"]:
            raise RuntimeError(f"{capture_id}: retained byte count changed")
        if digest(payload_path, "sha256") != record["sha256"]:
            raise RuntimeError(f"{capture_id}: retained SHA-256 changed")

        validation = dict(artifact["validation"])
        expected_md5 = validation.get("expectedPublisherMD5")
        if expected_md5 is not None:
            actual_md5 = digest(payload_path, "md5")
            if actual_md5 != expected_md5:
                raise RuntimeError(
                    f"{capture_id}: publisher MD5 {expected_md5} != {actual_md5}"
                )
            validation["publisherMD5Verification"] = "matched"
        validation.update(
            {
                "researchIngestionAuditID": record["auditID"],
                "researchIngestionCaptureStatus": record["captureStatus"],
                "researchIngestionQualityStatus": record["qualityStatus"],
                "researchIngestionFindings": record["qualityFindings"],
                "transportHTTPStatus": record["httpStatus"],
                "transportFinalURL": record["finalURL"],
                "transportMediaType": record["mediaType"],
            }
        )

        profile = plan["requestProfiles"][artifact["requestProfile"]]
        request = dict(profile)
        request.update(artifact["request"])
        captures.append(
            {
                "captureID": capture_id,
                "datasetID": artifact["datasetID"],
                "lane": artifact["lane"],
                "sourceURL": request["retrievalURL"],
                "retrievedAt": record["retrievedAtUTC"],
                "sourceVersion": request["sourceVersion"],
                "handlingClass": record["handlingClass"],
                "rightsStatus": record["licenseStatus"],
                "rightsBasis": record["rightsBasis"],
                "licenseSPDX": record.get("licenseSPDX"),
                "localUseOnly": record["localUseOnly"],
                "relativePath": str(payload_path.relative_to(repo_root)),
                "mediaType": record["mediaType"],
                "byteCount": record["byteCount"],
                "sha256": record["sha256"],
                "validation": validation,
                "evaluationRoles": artifact["evaluationRoles"],
            }
        )

        failure_path = failure_root / f"{capture_id}.json"
        if failure_path.exists():
            failure = load_json(failure_path)
            attempts.append(
                {
                    "attemptID": f"{capture_id}-initial-rejected",
                    "captureID": capture_id,
                    "datasetID": artifact["datasetID"],
                    "status": "rejected",
                    "reason": RETRY_REASON,
                    "returnCode": failure["returnCode"],
                    "retainedLocalEvidence": str(
                        failure_path.relative_to(repo_root)
                    ),
                }
            )
            rejected_count += 1

        attempts.append(
            {
                "attemptID": f"{capture_id}-{record['auditID']}",
                "captureID": capture_id,
                "datasetID": artifact["datasetID"],
                "status": "accepted",
                "retrievedAt": record["retrievedAtUTC"],
                "researchIngestionAuditID": record["auditID"],
                "sha256": record["sha256"],
                "byteCount": record["byteCount"],
            }
        )

    manifest["acceptedCaptures"] = captures
    manifest["status"] = "capture_promotion_audit_pending"
    for dataset in manifest["datasets"]:
        if dataset["datasetID"] == "medleydb":
            dataset["status"] = (
                "official_sample_acquired_full_audio_permission_pending"
            )
        elif dataset["datasetID"] == "mixassist":
            dataset["status"] = (
                "processed_dialogue_and_all_seven_aligned_audio_groups_acquired_"
                "dialogue_data_license_review_pending"
            )
        elif dataset["datasetID"] == "audioset":
            dataset["status"] = "supplemental_label_and_quality_scope_acquired"

    ledger["attempts"] = attempts
    ledger["acceptedArtifactCount"] = len(captures)
    ledger["rejectedArtifactCount"] = rejected_count
    ledger["status"] = "capture_promotion_audit_pending"
    ledger["lastAudit"] = None

    summary = {
        "schemaVersion": "1.0",
        "acceptedCaptureCount": len(captures),
        "rejectedAttemptCount": rejected_count,
        "acceptedDatasetIDs": sorted(
            {capture["datasetID"] for capture in captures}
        ),
        "acceptedLanes": sorted({capture["lane"] for capture in captures}),
        "acceptedByteCount": sum(capture["byteCount"] for capture in captures),
    }
    if args.write:
        write_json(manifest_path, manifest)
        write_json(ledger_path, ledger)
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
