#!/usr/bin/env python3
"""Validate a local Whisper JSON transcript and emit a text-free course index.

The output records provenance, coverage, timing, and chapter routing. It never
copies transcript text and never promotes transcription into deep source review.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import pathlib
import re
from typing import Any


ROOT = pathlib.Path(__file__).resolve().parents[2]
DEFAULT_LEDGER = ROOT / "research/metadata/local-production-course-review-v1.json"
DEFAULT_OUTPUT = (
    ROOT / "research/metadata/local-production-course-logic-pro-11-transcript-index-v1.json"
)
DEFAULT_RESOURCE_ID = "local-mastering-com-logic-pro-11-complete-tutorial"


def digest(path: pathlib.Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def timestamp_seconds(value: str) -> float:
    match = re.fullmatch(r"(\d{2}):(\d{2}):(\d{2})", value)
    if match is None:
        raise ValueError(f"invalid chapter timestamp: {value}")
    hours, minutes, seconds = map(int, match.groups())
    if minutes > 59 or seconds > 59:
        raise ValueError(f"invalid chapter timestamp: {value}")
    return float(hours * 3600 + minutes * 60 + seconds)


def source_record(ledger: dict[str, Any], resource_id: str) -> dict[str, Any]:
    matches = [source for source in ledger.get("sources", []) if source.get("resourceID") == resource_id]
    if len(matches) != 1:
        raise ValueError(f"expected one source record for {resource_id}, found {len(matches)}")
    return matches[0]


def chapter_ranges(
    source: dict[str, Any]
) -> tuple[list[dict[str, Any]], list[str], str]:
    parsed: list[tuple[float, str]] = []
    topical_queue: list[str] = []
    routing = source.get("chapterRouting", [])
    for item in routing:
        match = re.fullmatch(r"(\d{2}:\d{2}:\d{2})\s+(.+)", item)
        if match is None:
            topical_queue.append(item)
        else:
            parsed.append((timestamp_seconds(match.group(1)), match.group(2)))
    if parsed and topical_queue:
        raise ValueError("chapter routing cannot mix timestamped ranges and untimed topics")
    if not routing:
        raise ValueError("chapter routing must be nonempty")
    duration = float(source["durationSeconds"])
    if topical_queue:
        if not all(isinstance(item, str) and item.strip() for item in topical_queue):
            raise ValueError("untimed chapter topics must be nonempty strings")
        return ([{
            "order": 1,
            "title": "full-source navigation coverage; topic timestamps pending review",
            "startSeconds": 0.0,
            "endSeconds": duration,
        }], topical_queue, "topical_review_queue_without_timestamps")
    if parsed != sorted(parsed):
        raise ValueError("chapter routing must be nonempty and time-ordered")
    return ([
        {
            "order": index + 1,
            "title": title,
            "startSeconds": start,
            "endSeconds": parsed[index + 1][0] if index + 1 < len(parsed) else duration,
        }
        for index, (start, title) in enumerate(parsed)
    ], [], "exact_timestamp_ranges")


def validate_segments(payload: dict[str, Any], duration: float) -> list[dict[str, Any]]:
    segments = payload.get("segments")
    if not isinstance(segments, list) or len(segments) < 100:
        raise ValueError("transcript has too few segments for a long-form course")
    previous_end = 0.0
    result: list[dict[str, Any]] = []
    for index, segment in enumerate(segments):
        if not isinstance(segment, dict):
            raise ValueError(f"segment {index} is not an object")
        start = segment.get("start")
        end = segment.get("end")
        text = segment.get("text")
        if not isinstance(start, (int, float)) or not math.isfinite(start):
            raise ValueError(f"segment {index} has invalid start")
        if not isinstance(end, (int, float)) or not math.isfinite(end) or end <= start:
            raise ValueError(f"segment {index} has invalid end")
        if start < -0.001 or end > duration + 5:
            raise ValueError(f"segment {index} is outside source duration")
        if start + 2 < previous_end:
            raise ValueError(f"segment {index} has an implausible time reversal")
        if not isinstance(text, str) or not text.strip():
            raise ValueError(f"segment {index} has no useful recognized text")
        result.append({"index": index, "start": float(start), "end": float(end)})
        previous_end = max(previous_end, float(end))
    coverage = result[-1]["end"] / duration
    if coverage < 0.98 or coverage > 1.01:
        raise ValueError(f"transcript endpoint coverage is implausible: {coverage:.6f}")
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("transcript", type=pathlib.Path)
    parser.add_argument("--ledger", type=pathlib.Path, default=DEFAULT_LEDGER)
    parser.add_argument("--resource-id", default=DEFAULT_RESOURCE_ID)
    parser.add_argument("--output", type=pathlib.Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--engine", default="openai-whisper")
    parser.add_argument("--model", required=True)
    parser.add_argument("--language", required=True)
    args = parser.parse_args()

    if not args.transcript.is_file():
        raise ValueError(f"transcript file does not exist: {args.transcript}")
    ledger = json.loads(args.ledger.read_text(encoding="utf-8"))
    source = source_record(ledger, args.resource_id)
    if source.get("fullSourceReviewed") is not False:
        raise ValueError("transcript index cannot be generated from a source already mislabelled as reviewed")
    transcript = json.loads(args.transcript.read_text(encoding="utf-8"))
    duration = float(source["durationSeconds"])
    segments = validate_segments(transcript, duration)
    chapters, untimed_review_topics, chapter_routing_mode = chapter_ranges(source)

    gaps = []
    for previous, current in zip(segments, segments[1:]):
        gap = current["start"] - previous["end"]
        if gap > 10:
            gaps.append(
                {
                    "afterSegment": previous["index"],
                    "startSeconds": previous["end"],
                    "endSeconds": current["start"],
                    "durationSeconds": gap,
                }
            )

    chapter_coverage = []
    for chapter in chapters:
        members = [
            segment for segment in segments
            if chapter["startSeconds"] <= (segment["start"] + segment["end"]) / 2 < chapter["endSeconds"]
        ]
        chapter_coverage.append(
            {
                **chapter,
                "segmentCount": len(members),
                "firstSegmentIndex": members[0]["index"] if members else None,
                "lastSegmentIndex": members[-1]["index"] if members else None,
                "navigationStatus": "indexed_not_audiovisually_reviewed",
            }
        )
    if any(chapter["segmentCount"] == 0 for chapter in chapter_coverage):
        raise ValueError("one or more declared chapters has no transcript navigation coverage")

    payload = {
        "schemaVersion": "1.1",
        "resourceID": args.resource_id,
        "sourceTitle": source["title"],
        "sourcePayloadSHA256": source["sha256"],
        "sourceDurationSeconds": duration,
        "sourceReviewStatus": source["reviewStatus"],
        "sourceTranscriptIndexStatus": source["transcriptIndexStatus"],
        "fullSourceReviewed": False,
        "transcript": {
            "engine": args.engine,
            "model": args.model,
            "requestedLanguage": args.language,
            "detectedLanguage": transcript.get("language"),
            "localWorkingPath": str(args.transcript),
            "sha256": digest(args.transcript),
            "handling": "ignored_local_navigation_only_no_raw_text_committed",
            "segmentCount": len(segments),
            "firstSegmentStartSeconds": segments[0]["start"],
            "lastSegmentEndSeconds": segments[-1]["end"],
            "endpointCoverageRatio": segments[-1]["end"] / duration,
            "gapsOverTenSeconds": gaps,
        },
        "chapterRoutingMode": chapter_routing_mode,
        "untimedReviewTopics": untimed_review_topics,
        "chapterCoverage": chapter_coverage,
        "reviewBoundary": {
            "transcriptionCountsAsDeepReview": False,
            "audioReviewed": False,
            "visualSettingsReviewed": False,
            "audibleABReviewed": False,
            "logic12_3CrossCheckComplete": False,
            "claimsAdmittedToProductionKnowledge": False,
            "limitations": [
                "ASR can misrecognize technical terms and parameter values.",
                "Transcript text omits on-screen routing, settings, and gestures.",
                "A transcript cannot preserve or evaluate audible A/B examples.",
                *(
                    ["The source teaches Logic Pro 11 and must be checked against Logic Pro 12.3."]
                    if "Logic Pro 11" in source["title"]
                    else [
                        "Course claims are professional-practice evidence and require primary DSP, Logic, measurement, and listening cross-checks."
                    ]
                ),
            ],
        },
    }
    args.output.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(
        f"wrote {args.output}: segments={len(segments)} chapters={len(chapters)} "
        f"coverage={payload['transcript']['endpointCoverageRatio']:.6f}"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, json.JSONDecodeError) as error:
        raise SystemExit(f"LOCAL_COURSE_TRANSCRIPT_INDEX failed: {error}")
