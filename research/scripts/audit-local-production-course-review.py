#!/usr/bin/env python3
"""Fail-closed audit for TrackSmith's local long-form course review ledger."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import pathlib
import subprocess
import sys
from typing import Any


ROOT = pathlib.Path(__file__).resolve().parents[2]
DEFAULT_LEDGER = ROOT / "research/metadata/local-production-course-review-v1.json"
ALLOWED_REVIEW_STATES = {
    "indexed-not-reviewed",
    "transcript-indexing-in-progress-not-reviewed",
    "quarantined-for-identity-not-reviewed",
    "section-review-in-progress",
    "full-audiovisual-review-complete",
}
ALLOWED_TRANSCRIPT_STATES = {
    "not-started",
    "in-progress-base-model-navigation-only",
    "navigation-index-complete-unverified",
    "navigation-index-complete-spot-checked",
}


def fail(message: str) -> None:
    raise ValueError(message)


def sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def ffprobe_duration(path: pathlib.Path) -> float:
    result = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=noprint_wrappers=1:nokey=1",
            str(path),
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    return float(result.stdout.strip())


def require_string(item: dict[str, Any], key: str) -> str:
    value = item.get(key)
    if not isinstance(value, str) or not value.strip():
        fail(f"{item.get('resourceID', '<unknown>')}: {key} must be a nonempty string")
    return value


def audit_source(
    item: dict[str, Any], *, verify_hashes: bool, verify_durations: bool
) -> tuple[str, int]:
    resource_id = require_string(item, "resourceID")
    require_string(item, "title")
    require_string(item, "publisher")
    require_string(item, "canonicalIdentityStatus")

    expected_hash = require_string(item, "sha256")
    if len(expected_hash) != 64 or any(char not in "0123456789abcdef" for char in expected_hash):
        fail(f"{resource_id}: sha256 is not lowercase hexadecimal")

    expected_bytes = item.get("byteCount")
    if not isinstance(expected_bytes, int) or expected_bytes <= 0:
        fail(f"{resource_id}: byteCount must be a positive integer")

    expected_duration = item.get("durationSeconds")
    if not isinstance(expected_duration, (int, float)) or not math.isfinite(expected_duration) or expected_duration <= 0:
        fail(f"{resource_id}: durationSeconds must be finite and positive")

    path = pathlib.Path(require_string(item, "localPayloadPath"))
    if not path.is_absolute() or not path.is_file():
        fail(f"{resource_id}: local payload is absent or not a regular file: {path}")
    if path.stat().st_size != expected_bytes:
        fail(f"{resource_id}: byte count changed ({path.stat().st_size} != {expected_bytes})")

    review_status = item.get("reviewStatus")
    if review_status not in ALLOWED_REVIEW_STATES:
        fail(f"{resource_id}: invalid reviewStatus {review_status!r}")
    transcript_status = item.get("transcriptIndexStatus")
    if transcript_status not in ALLOWED_TRANSCRIPT_STATES:
        fail(f"{resource_id}: invalid transcriptIndexStatus {transcript_status!r}")

    full_reviewed = item.get("fullSourceReviewed")
    if not isinstance(full_reviewed, bool):
        fail(f"{resource_id}: fullSourceReviewed must be boolean")
    if full_reviewed != (review_status == "full-audiovisual-review-complete"):
        fail(f"{resource_id}: fullSourceReviewed and reviewStatus disagree")
    if "transcript" in review_status and full_reviewed:
        fail(f"{resource_id}: transcription cannot imply full source review")

    routing = item.get("chapterRouting")
    if not isinstance(routing, list) or not routing or not all(isinstance(x, str) and x.strip() for x in routing):
        fail(f"{resource_id}: chapterRouting must contain nonempty strings")
    cross_checks = item.get("crossChecksRequired")
    if not isinstance(cross_checks, list) or len(cross_checks) < 2:
        fail(f"{resource_id}: at least two cross-checks are required")

    if review_status == "quarantined-for-identity-not-reviewed":
        if item.get("canonicalItemURL") is not None:
            fail(f"{resource_id}: identity-quarantined source cannot claim a canonical item URL")

    if verify_hashes:
        actual_hash = sha256(path)
        if actual_hash != expected_hash:
            fail(f"{resource_id}: SHA-256 changed ({actual_hash} != {expected_hash})")
    if verify_durations:
        actual_duration = ffprobe_duration(path)
        if abs(actual_duration - float(expected_duration)) > 0.01:
            fail(f"{resource_id}: duration changed ({actual_duration} != {expected_duration})")

    return resource_id, expected_bytes


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ledger", type=pathlib.Path, default=DEFAULT_LEDGER)
    parser.add_argument("--verify-hashes", action="store_true")
    parser.add_argument("--verify-durations", action="store_true")
    args = parser.parse_args()

    payload = json.loads(args.ledger.read_text(encoding="utf-8"))
    if payload.get("schemaVersion") != 1:
        fail("unsupported schemaVersion")
    policy = payload.get("handlingPolicy")
    if not isinstance(policy, dict):
        fail("handlingPolicy is required")
    required_false = (
        "redistributionPermitted",
        "trainingRightsInferred",
        "sourceMediaMayBeCopiedIntoRepository",
        "rawTranscriptMayBeCommitted",
    )
    for key in required_false:
        if policy.get(key) is not False:
            fail(f"handlingPolicy.{key} must remain false")
    if policy.get("localUseOnly") is not True:
        fail("handlingPolicy.localUseOnly must remain true")
    if policy.get("transcriptRole") != "navigation index only":
        fail("transcriptRole must remain navigation-only")

    sources = payload.get("sources")
    if not isinstance(sources, list) or len(sources) != 8:
        fail("exactly eight user-supplied course identities are expected in v1")

    ids: set[str] = set()
    hashes: set[str] = set()
    total_bytes = 0
    for source in sources:
        if not isinstance(source, dict):
            fail("every source must be an object")
        resource_id, byte_count = audit_source(
            source,
            verify_hashes=args.verify_hashes,
            verify_durations=args.verify_durations,
        )
        if resource_id in ids:
            fail(f"duplicate resourceID: {resource_id}")
        ids.add(resource_id)
        digest = source["sha256"]
        if digest in hashes:
            fail(f"duplicate source payload hash: {digest}")
        hashes.add(digest)
        total_bytes += byte_count

    modes = ["metadata", "size"]
    if args.verify_hashes:
        modes.append("sha256")
    if args.verify_durations:
        modes.append("duration")
    print(
        f"LOCAL_COURSE_AUDIT passed={len(sources)} failed=0 "
        f"bytes={total_bytes} checks={','.join(modes)}"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, subprocess.CalledProcessError, ValueError, json.JSONDecodeError) as error:
        print(f"LOCAL_COURSE_AUDIT failed: {error}", file=sys.stderr)
        raise SystemExit(1)
