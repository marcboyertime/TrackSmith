#!/usr/bin/env python3
"""Acquire declared TrackSmith audio-evidence artifacts through ResearchIngestCLI."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any


DEFAULT_PLAN = (
    "research/evaluation/production-mastery-v1/audio-evidence-corpus/"
    "acquisition-plan.json"
)

REQUIRED_REQUEST_KEYS = {
    "resourceID",
    "title",
    "publisherOrAuthors",
    "evidenceRole",
    "canonicalURL",
    "retrievalURL",
    "sourceVersion",
    "captureMode",
    "expectedMediaTypes",
    "minimumByteCount",
    "minimumPageCount",
    "minimumUsefulTextCharacters",
    "requiresExtractableText",
    "handlingClass",
    "rightsBasis",
    "licenseStatus",
    "localUseOnly",
    "replacementPolicy",
    "notes",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--plan", default=DEFAULT_PLAN)
    selector = parser.add_mutually_exclusive_group()
    selector.add_argument("--capture-id", action="append", default=[])
    selector.add_argument("--dataset")
    selector.add_argument("--all", action="store_true")
    parser.add_argument(
        "--force",
        action="store_true",
        help="Repeat an acquisition even when a retained accepted record exists.",
    )
    return parser.parse_args()


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(
        json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    temporary.replace(path)


def select_artifacts(plan: dict[str, Any], args: argparse.Namespace) -> list[dict[str, Any]]:
    artifacts = plan["artifacts"]
    if args.capture_id:
        requested = set(args.capture_id)
        selected = [item for item in artifacts if item["captureID"] in requested]
        missing = sorted(requested - {item["captureID"] for item in selected})
        if missing:
            raise ValueError(f"unknown capture IDs: {missing}")
        return selected
    if args.dataset:
        selected = [item for item in artifacts if item["datasetID"] == args.dataset]
        if not selected:
            raise ValueError(f"no artifacts declared for dataset {args.dataset}")
        return selected
    if args.all:
        return [item for item in artifacts if item.get("enabled", True)]
    raise ValueError("select --capture-id, --dataset, or --all")


def expanded_request(
    plan: dict[str, Any], artifact: dict[str, Any]
) -> dict[str, Any]:
    profile_name = artifact["requestProfile"]
    profiles = plan["requestProfiles"]
    if profile_name not in profiles:
        raise ValueError(
            f"{artifact['captureID']}: unknown request profile {profile_name}"
        )
    request = dict(profiles[profile_name])
    request.update(artifact["request"])
    request.setdefault("licenseSPDX", None)
    request.setdefault("supersedesSHA256", None)
    request.setdefault("replacementReason", None)
    missing = sorted(REQUIRED_REQUEST_KEYS - set(request))
    if missing:
        raise ValueError(f"{artifact['captureID']}: missing request keys {missing}")
    for key in ("canonicalURL", "retrievalURL"):
        if not request[key].startswith("https://"):
            raise ValueError(
                f"{artifact['captureID']}: {key} must use an explicit HTTPS URL"
            )
    return request


def main() -> int:
    args = parse_args()
    repo_root = Path(__file__).resolve().parents[2]
    plan_path = Path(args.plan)
    if not plan_path.is_absolute():
        plan_path = repo_root / plan_path
    plan = json.loads(plan_path.read_text(encoding="utf-8"))
    artifacts = select_artifacts(plan, args)

    local_root = repo_root / plan["localRoot"]
    archive_root = local_root / "archive"
    request_root = local_root / "requests"
    record_root = local_root / "capture-records"
    failure_root = local_root / "failed-attempts"
    archive_root.mkdir(parents=True, exist_ok=True)

    summary: dict[str, Any] = {
        "schemaVersion": "1.0",
        "plan": str(plan_path.relative_to(repo_root)),
        "selectedCaptureIDs": [item["captureID"] for item in artifacts],
        "results": [],
    }
    exit_code = 0

    for artifact in artifacts:
        capture_id = artifact["captureID"]
        record_path = record_root / f"{capture_id}.json"
        if record_path.exists() and not args.force:
            retained = json.loads(record_path.read_text(encoding="utf-8"))
            if retained.get("captureStatus") in {"accepted", "duplicate"}:
                summary["results"].append(
                    {"captureID": capture_id, "status": "retained_record_reused"}
                )
                continue

        request = expanded_request(plan, artifact)
        request_path = request_root / f"{capture_id}.json"
        write_json(request_path, request)
        process = subprocess.run(
            [
                "swift",
                "run",
                "ResearchIngestCLI",
                "fetch",
                str(request_path),
                str(archive_root),
            ],
            cwd=repo_root,
            check=False,
            capture_output=True,
            text=True,
        )
        if process.returncode != 0:
            failure = {
                "schemaVersion": "1.0",
                "captureID": capture_id,
                "status": "rejected_or_transport_failed",
                "returnCode": process.returncode,
                "stderr": process.stderr,
            }
            write_json(failure_root / f"{capture_id}.json", failure)
            summary["results"].append(failure)
            exit_code = 1
            continue

        try:
            record = json.loads(process.stdout)
        except json.JSONDecodeError as error:
            failure = {
                "schemaVersion": "1.0",
                "captureID": capture_id,
                "status": "invalid_cli_record",
                "error": str(error),
                "stdout": process.stdout,
                "stderr": process.stderr,
            }
            write_json(failure_root / f"{capture_id}.json", failure)
            summary["results"].append(failure)
            exit_code = 1
            continue

        if record.get("captureStatus") not in {"accepted", "duplicate"}:
            raise RuntimeError(
                f"{capture_id}: unexpected capture status "
                f"{record.get('captureStatus')}"
            )
        write_json(record_path, record)
        summary["results"].append(
            {
                "captureID": capture_id,
                "status": record["captureStatus"],
                "sha256": record.get("sha256"),
                "byteCount": record.get("byteCount"),
                "localPath": record.get("localPath"),
            }
        )

    write_json(local_root / "last-acquisition-summary.json", summary)
    sys.stdout.write(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
