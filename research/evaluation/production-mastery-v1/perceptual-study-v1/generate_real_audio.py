#!/usr/bin/env python3
"""Prepare an opaque, six-fixture real-audio G5 listening pilot.

This generator is deliberately separate from ``generate_study.py``.  The latter
continues to prepare the historical 24-excerpt natural-audio study.  This module
only copies the six checked-in source/candidate WAV pairs into opaque condition
filenames; it never downloads audio, rewrites PCM, or invents response data.

The generated condition roles and fixture identities are retained in the
operator-only answer key.  The participant manifest has only anonymous trial and
condition labels.  BS.1770 measurements are produced by ``analyze_real_audio.py``
after generation so that the two deterministic steps remain auditable.
"""

from __future__ import annotations

import argparse
import hashlib
import math
import json
import random
import shutil
import struct
from pathlib import Path
from typing import Any


PACKAGE_DIR = Path(__file__).resolve().parent
REPO_ROOT = PACKAGE_DIR.parents[3]
FIXTURE_DIR = REPO_ROOT / "research/evaluation/production-mastery-v1/dsp-listening-fixtures"
GENERATED_DIR = PACKAGE_DIR / "generated"
REAL_AUDIO_DIR = GENERATED_DIR / "real-audio-pilot"
AUDIO_DIR = REAL_AUDIO_DIR / "audio"
FIXTURE_MANIFEST_PATH = FIXTURE_DIR / "manifest.json"

PILOT_ID = "tracksmith-g5-real-audio-six-fixture-pilot"
EVIDENCE_CLASS = "SINGLE_LISTENER_FORMATIVE_EVIDENCE"
SCHEMA_VERSION = "1.0"
SEED = 20260802
TOLERANCE_LU = 0.5
TRUE_PEAK_CEILING_DBTP = -1.0

PARTICIPANT_MANIFEST_PATH = GENERATED_DIR / "real-audio-pilot-participant-manifest.json"
ANSWER_KEY_PATH = GENERATED_DIR / "real-audio-pilot-answer-key.json"
PARTICIPANT_TEMPLATE_PATH = GENERATED_DIR / "real-audio-pilot-participant-response-template.json"
OPERATOR_TEMPLATE_PATH = GENERATED_DIR / "real-audio-pilot-operator-response-template.json"
GENERATION_REPORT_PATH = GENERATED_DIR / "real-audio-pilot-generation.json"


def load_json(path: Path) -> Any:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _read_chunk_header(data: bytes, offset: int) -> tuple[bytes, int, int]:
    if offset + 8 > len(data):
        raise ValueError("truncated RIFF chunk header")
    chunk_id = data[offset : offset + 4]
    chunk_size = struct.unpack_from("<I", data, offset + 4)[0]
    chunk_data = offset + 8
    if chunk_data + chunk_size > len(data):
        raise ValueError(f"truncated RIFF chunk {chunk_id!r}")
    return chunk_id, chunk_size, chunk_data


def parse_wav(path: Path) -> dict[str, Any]:
    """Parse the small PCM WAV contract used by the checked-in fixtures.

    The standard-library ``wave`` module does not accept IEEE-float WAV files on
    all supported Python versions, so this parser validates the RIFF/fmt/data
    chunks directly and does not decode or rewrite the payload.
    """

    data = path.read_bytes()
    if len(data) < 12 or data[:4] != b"RIFF" or data[8:12] != b"WAVE":
        raise ValueError(f"not a RIFF/WAVE file: {path}")
    offset = 12
    fmt: dict[str, Any] | None = None
    data_offset: int | None = None
    data_size: int | None = None
    while offset < len(data):
        chunk_id, chunk_size, chunk_data = _read_chunk_header(data, offset)
        if chunk_id == b"fmt ":
            if chunk_size < 16:
                raise ValueError(f"short fmt chunk: {path}")
            audio_format, channels, sample_rate, byte_rate, block_align, bits = struct.unpack_from(
                "<HHIIHH", data, chunk_data
            )
            if audio_format == 0xFFFE and chunk_size >= 40:
                # WAVE_FORMAT_EXTENSIBLE stores the real format in the first
                # two bytes of the 16-byte sub-format GUID.
                audio_format = struct.unpack_from("<H", data, chunk_data + 24)[0]
            fmt = {
                "audioFormat": audio_format,
                "channels": channels,
                "sampleRate": sample_rate,
                "byteRate": byte_rate,
                "blockAlign": block_align,
                "bitsPerSample": bits,
            }
        elif chunk_id == b"data":
            data_offset = chunk_data
            data_size = chunk_size
        offset = chunk_data + chunk_size + (chunk_size & 1)
    if fmt is None or data_offset is None or data_size is None:
        raise ValueError(f"WAV missing fmt/data chunks: {path}")
    if fmt["audioFormat"] not in (1, 3):
        raise ValueError(f"unsupported WAV format tag {fmt['audioFormat']}: {path}")
    if fmt["channels"] < 1 or fmt["sampleRate"] < 1 or fmt["blockAlign"] < 1:
        raise ValueError(f"invalid WAV stream metadata: {path}")
    if data_size % fmt["blockAlign"]:
        raise ValueError(f"WAV data is not frame aligned: {path}")
    frame_count = data_size // fmt["blockAlign"]
    return {
        "container": "RIFF/WAVE",
        "format": "PCM" if fmt["audioFormat"] == 1 else "IEEE_FLOAT",
        "audioFormat": fmt["audioFormat"],
        "channels": fmt["channels"],
        "sampleRate": fmt["sampleRate"],
        "bitsPerSample": fmt["bitsPerSample"],
        "blockAlign": fmt["blockAlign"],
        "frameCount": frame_count,
        "durationSeconds": round(frame_count / fmt["sampleRate"], 9),
        "byteCount": len(data),
        "dataByteCount": data_size,
    }


def questions() -> list[dict[str, str]]:
    """The existing plain-language response dimensions, kept verbatim."""

    return [
        {
            "id": "target_success",
            "prompt": "Did the change do what it was meant to do?",
            "scale": "0_not_at_all_to_6_completely",
        },
        {
            "id": "preservation",
            "prompt": "Did the important parts stay intact?",
            "scale": "0_not_at_all_to_6_completely",
        },
        {
            "id": "naturalness",
            "prompt": "Does it sound natural rather than processed?",
            "scale": "0_not_natural_to_6_very_natural",
        },
        {
            "id": "clarity",
            "prompt": "How clear is the sound?",
            "scale": "0_not_clear_to_6_very_clear",
        },
        {
            "id": "production_value",
            "prompt": "Does it make the production more useful or polished?",
            "scale": "0_not_at_all_to_6_a_lot",
        },
        {
            "id": "excitement",
            "prompt": "How engaging or exciting is it?",
            "scale": "0_not_at_all_to_6_very_much",
        },
        {
            "id": "preference",
            "prompt": "Which condition would you choose for this task?",
            "scale": "choose_one_presented_condition",
        },
        {
            "id": "confidence",
            "prompt": "How sure are you about your answers?",
            "scale": "0_not_sure_to_6_very_sure",
        },
    ]


def _safe_fixture_path(relative_path: str) -> Path:
    path = (FIXTURE_DIR / relative_path).resolve()
    fixture_root = FIXTURE_DIR.resolve()
    if path.parent != fixture_root:
        raise ValueError(f"fixture artifact must be directly under the checked-in fixture directory: {relative_path}")
    return path


def _condition_file(trial_number: int, label: str) -> Path:
    return AUDIO_DIR / f"stimulus-{trial_number:03d}-{label}.wav"


def _copy_condition(source: Path, destination: Path, gain_db: float = 0.0) -> dict[str, Any]:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if gain_db == 0.0:
        shutil.copyfile(source, destination)
    else:
        payload = bytearray(source.read_bytes())
        descriptor = parse_wav(source)
        if descriptor["format"] != "IEEE_FLOAT" or descriptor["bitsPerSample"] != 32:
            raise ValueError(f"gain correction requires 32-bit float WAV: {source}")
        offset = 12
        data_offset = None
        data_size = None
        while offset < len(payload):
            chunk_id, chunk_size, chunk_data = _read_chunk_header(payload, offset)
            if chunk_id == b"data":
                data_offset, data_size = chunk_data, chunk_size
                break
            offset = chunk_data + chunk_size + (chunk_size & 1)
        if data_offset is None or data_size is None:
            raise ValueError(f"WAV data chunk missing: {source}")
        scale = math.pow(10.0, gain_db / 20.0)
        for sample_offset in range(data_offset, data_offset + data_size, 4):
            sample = struct.unpack_from("<f", payload, sample_offset)[0]
            if not math.isfinite(sample):
                raise ValueError(f"nonfinite source sample in gain correction: {source}")
            struct.pack_into("<f", payload, sample_offset, max(-1.0, min(1.0, sample * scale)))
        destination.write_bytes(payload)
    descriptor = parse_wav(destination)
    descriptor["sha256"] = sha256_file(destination)
    descriptor["gainCorrectionDB"] = gain_db
    return descriptor


def _fixture_rows(manifest: dict[str, Any]) -> list[dict[str, Any]]:
    fixtures = manifest.get("fixtures")
    if not isinstance(fixtures, list) or len(fixtures) != 6:
        raise ValueError(f"expected exactly six checked-in DSP fixtures, got {len(fixtures or [])}")
    rows = sorted(fixtures, key=lambda row: row["identifier"])
    identifiers = [row.get("identifier") for row in rows]
    if len(set(identifiers)) != len(identifiers) or any(not isinstance(item, str) for item in identifiers):
        raise ValueError("fixture identifiers must be unique strings")
    return rows


def build_pilot(seed: int = SEED) -> dict[str, Any]:
    manifest = load_json(FIXTURE_MANIFEST_PATH)
    fixtures = _fixture_rows(manifest)
    rng = random.Random(seed)

    # A deterministic role permutation conceals which opaque label is source,
    # candidate, or the source-byte anchor.  The mapping never enters the
    # participant-facing manifest.
    role_names = ["reference", "target", "anchor"]
    condition_labels = ["A", "B", "C"]
    trials: list[dict[str, Any]] = []
    answer_trials: list[dict[str, Any]] = []
    generation_artifacts: list[dict[str, Any]] = []

    for trial_number, fixture in enumerate(fixtures, start=1):
        source_artifact = fixture["sourceArtifact"]
        candidate_artifact = fixture["candidateArtifact"]
        source_path = _safe_fixture_path(source_artifact["path"])
        candidate_path = _safe_fixture_path(candidate_artifact["path"])
        if not source_path.is_file() or not candidate_path.is_file():
            raise FileNotFoundError(f"missing checked-in fixture WAV for {fixture['identifier']}")
        source_descriptor = parse_wav(source_path)
        candidate_descriptor = parse_wav(candidate_path)
        source_hash = sha256_file(source_path)
        candidate_hash = sha256_file(candidate_path)
        if source_hash != source_artifact["sha256"]:
            raise ValueError(f"source fixture hash changed: {fixture['identifier']}")
        if candidate_hash != candidate_artifact["sha256"]:
            raise ValueError(f"candidate fixture hash changed: {fixture['identifier']}")
        if source_descriptor["sampleRate"] != candidate_descriptor["sampleRate"]:
            raise ValueError(f"source/candidate sample-rate mismatch: {fixture['identifier']}")
        if source_descriptor["channels"] != candidate_descriptor["channels"]:
            raise ValueError(f"source/candidate channel-count mismatch: {fixture['identifier']}")

        labels = condition_labels[:]
        rng.shuffle(labels)
        role_to_label = dict(zip(role_names, labels))
        trial_ref = f"trial-{trial_number:03d}"
        trial_label = f"Trial {trial_number:03d}"
        operator_conditions: list[dict[str, Any]] = []
        participant_conditions: list[dict[str, Any]] = []

        for role in role_names:
            label = role_to_label[role]
            output_path = _condition_file(trial_number, label)
            input_path = source_path if role in ("reference", "anchor") else candidate_path
            gain_correction_db = 0.9 if fixture["identifier"] == "reverb-short-drum-room" and role == "target" else 0.0
            descriptor = _copy_condition(input_path, output_path, gain_correction_db)
            expected_hash = source_hash if role in ("reference", "anchor") else descriptor["sha256"]
            if descriptor["sha256"] != expected_hash:
                raise AssertionError(f"generated condition hash mismatch: {output_path}")
            relative_audio_path = str(output_path.relative_to(REAL_AUDIO_DIR))
            operator_condition = {
                "conditionLabel": label,
                "role": role,
                "artifactRef": f"stimulus-{trial_number:03d}-{label}",
                "audioFile": relative_audio_path,
                "sha256": descriptor["sha256"],
                "byteCount": descriptor["byteCount"],
                "wav": descriptor,
                "input": {
                    "path": str(input_path.relative_to(FIXTURE_DIR)),
                    "sha256": expected_hash,
                    "kind": "source" if role in ("reference", "anchor") else "candidate",
                    "inputSHA256": candidate_hash if role == "target" else source_hash,
                    "gainCorrectionDB": gain_correction_db,
                },
            }
            if role == "anchor":
                operator_condition["derivation"] = "byte-identical duplicate of the checked-in source reference"
            operator_conditions.append(operator_condition)
            participant_conditions.append(
                {
                    "conditionLabel": label,
                    "artifactRef": f"stimulus-{trial_number:03d}-{label}",
                    "audioFile": relative_audio_path,
                    "format": {
                        "container": descriptor["container"],
                        "format": descriptor["format"],
                        "channels": descriptor["channels"],
                        "sampleRate": descriptor["sampleRate"],
                        "bitsPerSample": descriptor["bitsPerSample"],
                        "frameCount": descriptor["frameCount"],
                        "durationSeconds": descriptor["durationSeconds"],
                    },
                }
            )

        answer_trials.append(
            {
                "trialRef": trial_ref,
                "trialLabel": trial_label,
                "fixtureIdentifier": fixture["identifier"],
                "processor": fixture["processor"],
                "sourceFixture": fixture["sourceFixture"],
                "intendedComparison": fixture["intendedComparison"],
                "preservationBoundary": fixture["preservationBoundary"],
                "sourceInputSHA256": fixture["sourceInputSHA256"],
                "sourceInputUnchanged": fixture["sourceInputUnchanged"],
                "conditions": sorted(operator_conditions, key=lambda item: item["conditionLabel"]),
                "responses": [],
            }
        )
        trials.append({"trialRef": trial_ref, "trialLabel": trial_label, "conditions": participant_conditions})
        generation_artifacts.extend(
            {
                "trialRef": trial_ref,
                "conditionLabel": condition["conditionLabel"],
                "audioFile": condition["audioFile"],
                "sha256": condition["sha256"],
            }
            for condition in operator_conditions
        )

    rng.shuffle(trials)
    participant_manifest = {
        "schemaVersion": SCHEMA_VERSION,
        "pilotID": PILOT_ID,
        "evidenceClass": EVIDENCE_CLASS,
        "status": "prepared_pending_human_participation",
        "pilotScope": "six_checked_in_dsp_fixture_pairs",
        "participantFacing": True,
        "identityDisclosure": "none",
        "claimBoundary": "Formative six-fixture pilot only; this is not a rendered 24-excerpt natural-audio study and contains no perceptual claim.",
        "trialCount": len(trials),
        "conditionsPerTrial": 3,
        "levelMatching": {
            "method": "ITU-R BS.1770 integrated loudness",
            "toleranceLU": TOLERANCE_LU,
            "truePeakCeilingDBTP": TRUE_PEAK_CEILING_DBTP,
            "measurementsIn": "real-audio-pilot-analysis.json",
        },
        "monitoringPrompt": "Record monitoring context separately before listening; do not enter participant identity here.",
        "questions": questions(),
        "trials": trials,
        "responses": [],
    }

    answer_key = {
        "schemaVersion": SCHEMA_VERSION,
        "pilotID": PILOT_ID,
        "evidenceClass": EVIDENCE_CLASS,
        "operatorOnly": True,
        "pilotScope": "six_checked_in_dsp_fixture_pairs",
        "randomizationSeed": seed,
        "randomizationAlgorithm": "Python random.Random(seed) role-label shuffle then trial shuffle",
        "candidateIdentitiesAreHiddenUntilJudgment": True,
        "participantManifest": "real-audio-pilot-participant-manifest.json",
        "analysisReport": "real-audio-pilot-analysis.json",
        "trials": answer_trials,
        "responses": [],
    }

    participant_response_template = {
        "schemaVersion": SCHEMA_VERSION,
        "templateType": "participant_response_template",
        "pilotID": PILOT_ID,
        "evidenceClass": EVIDENCE_CLASS,
        "participantFacing": True,
        "identityDisclosure": "none",
        "instructions": "Use only the opaque Trial and A/B/C labels after listening. Keep monitoring context outside this file. This template contains no responses.",
        "questions": questions(),
        "responseRecordSchema": {
            "trialRef": "trial-NNN",
            "conditionScores": "one score per presented A/B/C condition for each applicable question",
            "preference": "one of A, B, C",
            "confidence": "0-6",
            "freeText": "optional operator-approved note; no identity or source names",
        },
        "trials": [{"trialRef": trial["trialRef"], "trialLabel": trial["trialLabel"], "responses": []} for trial in trials],
        "responses": [],
    }
    operator_response_template = {
        "schemaVersion": SCHEMA_VERSION,
        "templateType": "operator_response_template",
        "pilotID": PILOT_ID,
        "evidenceClass": EVIDENCE_CLASS,
        "operatorOnly": True,
        "instructions": "Keep this ledger empty until the user explicitly conducts a listening session. Do not infer, backfill, or fabricate responses.",
        "participantManifest": "real-audio-pilot-participant-manifest.json",
        "answerKey": "real-audio-pilot-answer-key.json",
        "questions": questions(),
        "monitoringContextFields": [
            "listenerCode",
            "roomOrHeadphonePath",
            "interface",
            "sampleRate",
            "bitDepth",
            "playbackLevel",
            "date",
        ],
        "trials": [{"trialRef": trial["trialRef"], "trialLabel": trial["trialLabel"], "responses": []} for trial in trials],
        "responses": [],
    }

    generation_report = {
        "schemaVersion": SCHEMA_VERSION,
        "pilotID": PILOT_ID,
        "evidenceClass": EVIDENCE_CLASS,
        "status": "generated_pending_bs1770_analysis",
        "generator": "generate_real_audio.py",
        "randomizationSeed": seed,
        "inputs": {
            "fixtureManifest": {
                "path": "research/evaluation/production-mastery-v1/dsp-listening-fixtures/manifest.json",
                "sha256": sha256_file(FIXTURE_MANIFEST_PATH),
            }
        },
        "sourceAudioPolicy": "Use checked-in source/candidate WAV bytes only; no download or source-fixture modification. Generated participant conditions may apply a deterministic bounded gain correction to a candidate copy solely for the declared BS.1770 level-match gate.",
        "conditionCount": len(generation_artifacts),
        "trialCount": len(trials),
        "artifactHashes": sorted(generation_artifacts, key=lambda item: (item["trialRef"], item["conditionLabel"])),
        "participantResponses": 0,
        "claimBoundary": "Generation is preparation evidence only; no human response or perceptual-success claim.",
    }

    return {
        "participantManifest": participant_manifest,
        "answerKey": answer_key,
        "participantResponseTemplate": participant_response_template,
        "operatorResponseTemplate": operator_response_template,
        "generationReport": generation_report,
    }


def write_pilot(seed: int = SEED) -> dict[str, Path]:
    # Remove only the owned, deterministic condition files before rebuilding;
    # do this before ``build_pilot`` copies the new bytes.
    for path in AUDIO_DIR.glob("stimulus-*.wav"):
        path.unlink()
    AUDIO_DIR.mkdir(parents=True, exist_ok=True)
    artifacts = build_pilot(seed)
    write_json(PARTICIPANT_MANIFEST_PATH, artifacts["participantManifest"])
    write_json(ANSWER_KEY_PATH, artifacts["answerKey"])
    write_json(PARTICIPANT_TEMPLATE_PATH, artifacts["participantResponseTemplate"])
    write_json(OPERATOR_TEMPLATE_PATH, artifacts["operatorResponseTemplate"])
    write_json(GENERATION_REPORT_PATH, artifacts["generationReport"])
    return {
        "participantManifest": PARTICIPANT_MANIFEST_PATH,
        "answerKey": ANSWER_KEY_PATH,
        "participantResponseTemplate": PARTICIPANT_TEMPLATE_PATH,
        "operatorResponseTemplate": OPERATOR_TEMPLATE_PATH,
        "generationReport": GENERATION_REPORT_PATH,
        "audioDir": AUDIO_DIR,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=int, default=SEED)
    args = parser.parse_args()
    paths = write_pilot(args.seed)
    report = load_json(paths["generationReport"])
    print(
        f"GENERATE_REAL_AUDIO_PASS pilot={PILOT_ID} seed={args.seed} "
        f"trials={report['trialCount']} conditions={report['conditionCount']} participant_responses=0"
    )
    for label, path in sorted(paths.items()):
        print(f"{label}={path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
