#!/usr/bin/env python3
"""Build a deterministic PCM and dialogue index for TrackSmith's audio corpus."""

from __future__ import annotations

import argparse
import array
import hashlib
import io
import json
import re
import sys
import tarfile
import wave
import zipfile
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Iterable


CORPUS_DIR = (
    "research/evaluation/production-mastery-v1/audio-evidence-corpus"
)
MIXASSIST_AUDIO_PATTERN = re.compile(
    r"(?:^|/)audio/segments/(Group[1-7])/([^/]+\.wav)$",
    re.IGNORECASE,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    return parser.parse_args()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def write_json(path: Path, value: Any) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(
        json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    temporary.replace(path)


def sample_values(data: bytes, sample_width: int) -> Iterable[int]:
    if sample_width == 1:
        for value in data:
            yield value - 128
    elif sample_width == 2:
        values = array.array("h")
        values.frombytes(data)
        if sys.byteorder != "little":
            values.byteswap()
        yield from values
    elif sample_width == 3:
        for offset in range(0, len(data), 3):
            value = int.from_bytes(
                data[offset : offset + 3], byteorder="little", signed=False
            )
            if value & 0x800000:
                value -= 1 << 24
            yield value
    elif sample_width == 4:
        values = array.array("i")
        values.frombytes(data)
        if sys.byteorder != "little":
            values.byteswap()
        yield from values
    else:
        raise ValueError(f"unsupported PCM sample width {sample_width}")


def inspect_pcm_wave(data: bytes) -> dict[str, Any]:
    with wave.open(io.BytesIO(data), "rb") as audio:
        channels = audio.getnchannels()
        sample_rate = audio.getframerate()
        sample_width = audio.getsampwidth()
        frame_count = audio.getnframes()
        compression = audio.getcomptype()
        if compression != "NONE":
            raise ValueError(f"unsupported WAV compression {compression}")
        if channels < 1 or sample_rate < 1 or frame_count < 1:
            raise ValueError("invalid or empty PCM WAV")

        maximum = (1 << (sample_width * 8 - 1)) - 1
        minimum = -(1 << (sample_width * 8 - 1))
        peak = 0
        clipped = 0
        zeros = 0
        sample_count = 0
        sample_sum = 0
        while True:
            frames = audio.readframes(65_536)
            if not frames:
                break
            for value in sample_values(frames, sample_width):
                magnitude = abs(value)
                peak = max(peak, magnitude)
                if value in {minimum, maximum}:
                    clipped += 1
                if value == 0:
                    zeros += 1
                sample_count += 1
                sample_sum += value

    scale = max(abs(minimum), maximum)
    normalized_peak = peak / scale
    return {
        "container": "RIFF_WAVE",
        "encoding": f"signed_pcm_{sample_width * 8}",
        "channels": channels,
        "sampleRate": sample_rate,
        "sampleWidthBytes": sample_width,
        "frameCount": frame_count,
        "sampleCount": sample_count,
        "durationSeconds": frame_count / sample_rate,
        "normalizedPeak": normalized_peak,
        "clippedSampleCount": clipped,
        "zeroSampleCount": zeros,
        "normalizedDCOffset": (
            sample_sum / sample_count / scale if sample_count else 0
        ),
        "silenceStatus": (
            "silent_or_near_silent" if normalized_peak <= 1e-5 else "audible"
        ),
    }


def load_mixassist_rows(
    repo_root: Path,
    local_root: Path,
    captures: dict[str, dict[str, Any]],
) -> tuple[dict[tuple[str, str], list[dict[str, Any]]], str]:
    dependency_root = local_root / "python"
    if dependency_root.exists():
        sys.path.insert(0, str(dependency_root))
    try:
        import pyarrow  # type: ignore
        import pyarrow.parquet as parquet  # type: ignore
    except ImportError as error:
        raise RuntimeError(
            "pyarrow is required only for pinned MixAssist parquet indexing; "
            f"install it under {dependency_root}"
        ) from error

    references: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
    split_captures = {
        "train": "mixassist-hf-train-bf375752",
        "validation": "mixassist-hf-validation-bf375752",
        "test": "mixassist-hf-test-bf375752",
    }
    for split, capture_id in split_captures.items():
        capture = captures[capture_id]
        path = repo_root / capture["relativePath"]
        table = parquet.read_table(path)
        expected_rows = capture["validation"]["expectedRowsFromPinnedCard"]
        if table.num_rows != expected_rows:
            raise RuntimeError(
                f"{capture_id}: parquet rows {table.num_rows} != {expected_rows}"
            )
        for row in table.to_pylist():
            candidates: list[tuple[str, str]] = []
            if row.get("audio_file"):
                candidates.append(("current_turn", row["audio_file"]))
            for history in row.get("input_history") or []:
                if history.get("audio_file"):
                    candidates.append(("history", history["audio_file"]))
            for reference_kind, audio_file in candidates:
                match = MIXASSIST_AUDIO_PATTERN.search(audio_file)
                if match is None:
                    continue
                group = match.group(1).title()
                filename = match.group(2)
                reference = {
                    "split": split,
                    "conversationID": row["conversation_id"],
                    "turnID": row["turn_id"],
                    "topic": row["topic"],
                    "hasContent": row["has_content"],
                    "referenceKind": reference_kind,
                    "userTextSHA256": sha256_bytes(
                        (row.get("user") or "").encode("utf-8")
                    ),
                    "assistantTextSHA256": sha256_bytes(
                        (row.get("assistant") or "").encode("utf-8")
                    ),
                }
                if reference not in references[(group, filename)]:
                    references[(group, filename)].append(reference)

    for item in references.values():
        item.sort(
            key=lambda value: (
                value["split"],
                value["conversationID"],
                value["turnID"],
                value["referenceKind"],
            )
        )
    return references, pyarrow.__version__


def build_medley_assets(
    repo_root: Path,
    capture: dict[str, Any],
) -> list[dict[str, Any]]:
    path = repo_root / capture["relativePath"]
    assets: list[dict[str, Any]] = []
    with tarfile.open(path, "r:gz") as archive:
        members = [member for member in archive.getmembers() if member.isfile()]
        annotations_by_track: dict[str, list[str]] = defaultdict(list)
        for member in members:
            for track in ("LizNelson_Rainfall", "Phoenix_ScotchMorris"):
                if track in member.name and not member.name.lower().endswith(".wav"):
                    annotations_by_track[track].append(member.name)
        for member in members:
            if (
                not member.name.lower().endswith(".wav")
                or Path(member.name).name.startswith("._")
            ):
                continue
            extracted = archive.extractfile(member)
            if extracted is None:
                raise RuntimeError(f"could not read tar member {member.name}")
            data = extracted.read()
            track = next(
                (
                    candidate
                    for candidate in (
                        "LizNelson_Rainfall",
                        "Phoenix_ScotchMorris",
                    )
                    if candidate in member.name
                ),
                "unknown",
            )
            if "_MIX.wav" in member.name:
                role = "mixture"
                source_class = "full_mix"
            elif "_STEMS/" in member.name:
                role = "processed_stem"
                source_class = "processed_stem"
            elif "_RAW/" in member.name:
                role = "raw_source"
                source_class = "raw_source"
            else:
                role = "unclassified_audio"
                source_class = "unknown"
            try:
                pcm = inspect_pcm_wave(data)
            except (ValueError, wave.Error, EOFError) as error:
                raise RuntimeError(
                    f"MedleyDB member {member.name} failed PCM validation: {error}"
                ) from error
            assets.append(
                {
                    "assetID": f"medleydb:{member.name}",
                    "datasetID": "medleydb",
                    "sourceCaptureID": capture["captureID"],
                    "sourceCaptureSHA256": capture["sha256"],
                    "memberPath": member.name,
                    "split": "tracksmith_holdout",
                    "splitProvenance": "tracksmith_local_evaluation_assignment",
                    "artifactSHA256": sha256_bytes(data),
                    "byteCount": len(data),
                    "sourceClass": source_class,
                    "role": role,
                    "trackID": track,
                    "datasetAnnotationMemberPaths": sorted(
                        annotations_by_track[track]
                    ),
                    "pcm": pcm,
                    "evaluationRoles": capture["evaluationRoles"],
                }
            )
    return assets


def build_mixassist_assets(
    repo_root: Path,
    capture: dict[str, Any],
    references: dict[tuple[str, str], list[dict[str, Any]]],
) -> list[dict[str, Any]]:
    path = repo_root / capture["relativePath"]
    match = re.search(r"group([1-7])", capture["captureID"])
    if match is None:
        raise RuntimeError(f"cannot identify MixAssist group: {capture['captureID']}")
    group = f"Group{match.group(1)}"
    assets: list[dict[str, Any]] = []
    with zipfile.ZipFile(path) as archive:
        for member in archive.infolist():
            filename = Path(member.filename).name
            if (
                member.is_dir()
                or "__MACOSX" in Path(member.filename).parts
                or filename.startswith("._")
                or not filename.lower().endswith(".wav")
            ):
                continue
            data = archive.read(member)
            dialogue_references = references.get((group, filename), [])
            splits = sorted(
                {reference["split"] for reference in dialogue_references}
            )
            topics = sorted(
                {reference["topic"] for reference in dialogue_references}
            )
            split = (
                "tracksmith_holdout"
                if group in {"Group6", "Group7"}
                else "evaluation"
            )
            try:
                pcm = inspect_pcm_wave(data)
            except (ValueError, wave.Error, EOFError) as error:
                raise RuntimeError(
                    f"MixAssist member {member.filename} failed PCM validation: {error}"
                ) from error
            assets.append(
                {
                    "assetID": f"mixassist:{group}:{filename}",
                    "datasetID": "mixassist",
                    "sourceCaptureID": capture["captureID"],
                    "sourceCaptureSHA256": capture["sha256"],
                    "memberPath": member.filename,
                    "split": split,
                    "sourceSplits": splits,
                    "sourceSplitContaminated": len(splits) > 1,
                    "splitProvenance": (
                        "tracksmith_session_disjoint_assignment_groups_1_to_5_"
                        "evaluation_groups_6_to_7_holdout"
                    ),
                    "artifactSHA256": sha256_bytes(data),
                    "byteCount": len(data),
                    "sourceClass": topics[0] if len(topics) == 1 else "mixed_or_unknown",
                    "sourceTopics": topics,
                    "role": "conversation_aligned_music_excerpt",
                    "groupID": group,
                    "dialogueReferences": dialogue_references,
                    "pcm": pcm,
                    "evaluationRoles": capture["evaluationRoles"],
                }
            )
    return assets


def build_index(repo_root: Path) -> dict[str, Any]:
    corpus_dir = repo_root / CORPUS_DIR
    manifest = load_json(corpus_dir / "dataset-manifest.json")
    captures = {
        capture["captureID"]: capture for capture in manifest["acceptedCaptures"]
    }
    local_root = repo_root / manifest["payloadRoot"]
    references, pyarrow_version = load_mixassist_rows(
        repo_root, local_root, captures
    )

    assets = build_medley_assets(
        repo_root, captures["medleydb-sample-zenodo-1438309"]
    )
    for capture_id in sorted(
        capture_id
        for capture_id in captures
        if capture_id.startswith("mixassist-audio-group")
    ):
        assets.extend(
            build_mixassist_assets(
                repo_root, captures[capture_id], references
            )
        )
    assets.sort(key=lambda asset: asset["assetID"])

    hash_splits: dict[str, set[str]] = defaultdict(set)
    hash_asset_ids: dict[str, list[str]] = defaultdict(list)
    for asset in assets:
        hash_splits[asset["artifactSHA256"]].add(asset["split"])
        hash_asset_ids[asset["artifactSHA256"]].append(asset["assetID"])
    declared_splits = {
        "train",
        "validation",
        "test",
        "evaluation",
        "tracksmith_holdout",
    }
    exact_split_leaks = [
        {
            "sha256": digest,
            "splits": sorted(splits & declared_splits),
            "assetIDs": sorted(hash_asset_ids[digest]),
        }
        for digest, splits in sorted(hash_splits.items())
        if len(splits & declared_splits) > 1
    ]
    if exact_split_leaks:
        raise RuntimeError(f"exact split leakage detected: {exact_split_leaks}")
    exact_duplicate_groups = [
        {
            "sha256": digest,
            "splits": sorted(hash_splits[digest]),
            "assetIDs": sorted(asset_ids),
        }
        for digest, asset_ids in sorted(hash_asset_ids.items())
        if len(asset_ids) > 1
    ]

    counts = Counter(asset["datasetID"] for asset in assets)
    role_counts = Counter(asset["role"] for asset in assets)
    sample_rates = Counter(asset["pcm"]["sampleRate"] for asset in assets)
    channels = Counter(asset["pcm"]["channels"] for asset in assets)
    silent_assets = [
        asset["assetID"]
        for asset in assets
        if asset["pcm"]["silenceStatus"] != "audible"
    ]
    released_split_contaminated_assets = [
        {
            "assetID": asset["assetID"],
            "releasedSourceSplits": asset["sourceSplits"],
        }
        for asset in assets
        if asset["datasetID"] == "mixassist"
        and asset["sourceSplitContaminated"]
    ]
    return {
        "schemaVersion": "1.0",
        "corpusID": manifest["corpusID"],
        "status": "indexed_pcm_validated",
        "generator": "research/scripts/build-audio-evidence-index.py",
        "generatorDependencies": {
            "python": sys.version.split()[0],
            "pyarrow": pyarrow_version,
        },
        "sourceCaptureSHA256s": {
            capture_id: capture["sha256"]
            for capture_id, capture in sorted(captures.items())
            if capture_id == "medleydb-sample-zenodo-1438309"
            or capture_id.startswith("mixassist-audio-group")
            or capture_id.startswith("mixassist-hf-")
        },
        "summary": {
            "assetCount": len(assets),
            "datasetAssetCounts": dict(sorted(counts.items())),
            "roleCounts": dict(sorted(role_counts.items())),
            "sampleRateCounts": {
                str(key): value for key, value in sorted(sample_rates.items())
            },
            "channelCountCounts": {
                str(key): value for key, value in sorted(channels.items())
            },
            "totalDurationSeconds": sum(
                asset["pcm"]["durationSeconds"] for asset in assets
            ),
            "silentOrNearSilentAssetIDs": silent_assets,
            "exactSplitLeakCount": 0,
            "exactDuplicateGroupCount": len(exact_duplicate_groups),
            "exactDuplicateGroups": exact_duplicate_groups,
            "releasedSplitContaminatedAssetCount": len(
                released_split_contaminated_assets
            ),
            "releasedSplitContaminatedAssets": (
                released_split_contaminated_assets
            ),
            "trackSmithSplitPolicy": (
                "MixAssist release splits are retained only as source "
                "provenance because identical audio crosses them. TrackSmith "
                "uses session-disjoint local evaluation and holdout groups."
            ),
            "unmatchedMixAssistAssetCount": sum(
                1
                for asset in assets
                if asset["datasetID"] == "mixassist"
                and not asset["dialogueReferences"]
            ),
        },
        "assets": assets,
    }


def main() -> int:
    args = parse_args()
    repo_root = Path(__file__).resolve().parents[2]
    target = repo_root / CORPUS_DIR / "natural-audio-index.json"
    result = build_index(repo_root)
    rendered = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.check:
        if not target.exists() or target.read_text(encoding="utf-8") != rendered:
            print("natural-audio index is stale", file=sys.stderr)
            return 1
    if args.write:
        write_json(target, result)
    print(
        json.dumps(
            {
                "assetCount": result["summary"]["assetCount"],
                "datasetAssetCounts": result["summary"]["datasetAssetCounts"],
                "totalDurationSeconds": result["summary"][
                    "totalDurationSeconds"
                ],
                "unmatchedMixAssistAssetCount": result["summary"][
                    "unmatchedMixAssistAssetCount"
                ],
                "exactSplitLeakCount": result["summary"][
                    "exactSplitLeakCount"
                ],
                "releasedSplitContaminatedAssetCount": result["summary"][
                    "releasedSplitContaminatedAssetCount"
                ],
            },
            indent=2,
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
