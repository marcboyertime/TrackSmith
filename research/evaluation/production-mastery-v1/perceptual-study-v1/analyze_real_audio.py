#!/usr/bin/env python3
"""Verify the generated six-fixture real-audio G5 pilot.

The analyzer is operator-only.  It validates every generated WAV container and
SHA-256, measures BS.1770 integrated loudness and true peak, records any bounded
level-match failure, and scans the participant artifacts for identity leaks or
responses.  It never edits source fixtures and never fabricates listening data.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

from generate_real_audio import (
    ANSWER_KEY_PATH,
    AUDIO_DIR,
    EVIDENCE_CLASS,
    FIXTURE_DIR,
    FIXTURE_MANIFEST_PATH,
    GENERATED_DIR,
    GENERATION_REPORT_PATH,
    PARTICIPANT_MANIFEST_PATH,
    PARTICIPANT_TEMPLATE_PATH,
    OPERATOR_TEMPLATE_PATH,
    PILOT_ID,
    REAL_AUDIO_DIR,
    SEED,
    TRUE_PEAK_CEILING_DBTP,
    TOLERANCE_LU,
    load_json,
    parse_wav,
    sha256_file,
)


ANALYSIS_REPORT_PATH = GENERATED_DIR / "real-audio-pilot-analysis.json"
REPO_ROOT = FIXTURE_DIR.parents[3]
DEFAULT_ANALYSIS_CLI = REPO_ROOT / ".build/debug/AnalysisCLI"


class AnalysisFailure(RuntimeError):
    pass


def write_json(path: Path, value: Any) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def walk_strings(value: Any) -> list[str]:
    if isinstance(value, str):
        return [value]
    if isinstance(value, list):
        result: list[str] = []
        for item in value:
            result.extend(walk_strings(item))
        return result
    if isinstance(value, dict):
        result = []
        for item in value.values():
            result.extend(walk_strings(item))
        return result
    return []


def _parse_metric_value(value: Any) -> float | None:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        if value.lower() in {"-infinity", "-inf", "inf", "+inf", "+infinity"}:
            return None
        return float(value)
    raise ValueError(f"unsupported meter value: {value!r}")


def _meter_with_analysis_cli(path: Path, analysis_cli: Path) -> dict[str, Any]:
    completed = subprocess.run(
        [str(analysis_cli), str(path)],
        cwd=REPO_ROOT,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        env=os.environ.copy(),
    )
    try:
        report = json.loads(completed.stdout)
        metrics = report["metrics"]
        integrated = _parse_metric_value(metrics["integrated_loudness_lufs"]["value"])
        true_peak = _parse_metric_value(metrics["true_peak_dbtp"]["value"])
    except (KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
        raise AnalysisFailure(f"AnalysisCLI returned an unexpected report for {path}: {error}") from error
    return {
        "meter": "TrackSmith AudioAnalysis BS1770Meter",
        "meterVersion": report.get("version"),
        "integratedLoudnessLUFS": integrated,
        "truePeakDBTP": true_peak,
        "sampleRate": report.get("sampleRate"),
        "frameCount": report.get("frameCount"),
    }


def _meter_with_ffmpeg(path: Path) -> dict[str, Any]:
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        raise AnalysisFailure("no TrackSmith AnalysisCLI or ffmpeg ebur128 meter is available")
    completed = subprocess.run(
        [
            ffmpeg,
            "-hide_banner",
            "-nostats",
            "-i",
            str(path),
            "-filter_complex",
            "ebur128=peak=true:framelog=quiet",
            "-f",
            "null",
            "-",
        ],
        cwd=REPO_ROOT,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        env={**os.environ, "LC_ALL": "C"},
    )
    integrated_match = re.search(r"^\s*I:\s*([-+]?\d+(?:\.\d+)?|[-+]?Inf(?:inity)?)\s+LUFS", completed.stderr, re.MULTILINE | re.IGNORECASE)
    true_peak_match = re.search(r"^\s*Peak:\s*([-+]?\d+(?:\.\d+)?|[-+]?Inf(?:inity)?)\s+dBFS", completed.stderr, re.MULTILINE | re.IGNORECASE)
    if integrated_match is None or true_peak_match is None:
        raise AnalysisFailure(f"ffmpeg ebur128 summary did not contain loudness and true peak for {path}")
    return {
        "meter": "ffmpeg ebur128 fallback (BS.1770-style summary)",
        "meterVersion": None,
        "integratedLoudnessLUFS": _parse_metric_value(integrated_match.group(1)),
        "truePeakDBTP": _parse_metric_value(true_peak_match.group(1)),
        "sampleRate": None,
        "frameCount": None,
    }


def measure(path: Path, analysis_cli: Path | None) -> dict[str, Any]:
    if analysis_cli is not None and analysis_cli.is_file() and analysis_cli.stat().st_mode & 0o111:
        try:
            return _meter_with_analysis_cli(path, analysis_cli)
        except (OSError, subprocess.CalledProcessError, AnalysisFailure) as error:
            # A stale local build should not make the verification silently pass;
            # the fallback is explicit in the report and remains deterministic.
            fallback = _meter_with_ffmpeg(path)
            fallback["fallbackReason"] = str(error)
            return fallback
    return _meter_with_ffmpeg(path)


def _fixture_identity_tokens(fixture_manifest: dict[str, Any]) -> set[str]:
    tokens: set[str] = set()
    for fixture in fixture_manifest["fixtures"]:
        tokens.add(fixture["identifier"])
        tokens.add(fixture["sourceFixture"])
        for artifact_key in ("sourceArtifact", "candidateArtifact", "planArtifact", "analysisArtifact"):
            artifact = fixture[artifact_key]
            tokens.add(artifact["path"])
            tokens.add(artifact["sha256"])
        tokens.add(fixture["sourceInputSHA256"])
    return {token for token in tokens if token}


def _assert_participant_boundary(
    participant: dict[str, Any],
    participant_template: dict[str, Any],
    fixture_manifest: dict[str, Any],
) -> list[str]:
    forbidden = _fixture_identity_tokens(fixture_manifest)
    participant_strings = "\n".join(walk_strings(participant))
    template_strings = "\n".join(walk_strings(participant_template))
    leaked = sorted(token for token in forbidden if token in participant_strings or token in template_strings)
    if participant.get("responses") != [] or participant_template.get("responses") != []:
        raise AnalysisFailure("participant manifest/template contains response records")
    if participant.get("participantFacing") is not True or participant.get("identityDisclosure") != "none":
        raise AnalysisFailure("participant manifest is not explicitly opaque")
    if participant_template.get("participantFacing") is not True or participant_template.get("identityDisclosure") != "none":
        raise AnalysisFailure("participant response template is not explicitly opaque")
    for trial in participant.get("trials", []):
        if not re.fullmatch(r"Trial [0-9]{3}", trial.get("trialLabel", "")):
            raise AnalysisFailure(f"non-opaque trial label: {trial.get('trialLabel')!r}")
        labels = [condition.get("conditionLabel") for condition in trial.get("conditions", [])]
        if set(labels) != {"A", "B", "C"}:
            raise AnalysisFailure(f"participant condition labels are not exactly A/B/C: {labels}")
        for condition in trial["conditions"]:
            if not re.fullmatch(r"stimulus-[0-9]{3}-[ABC]", condition.get("artifactRef", "")):
                raise AnalysisFailure(f"non-opaque artifact reference: {condition.get('artifactRef')!r}")
    return leaked


def _inside_real_audio(path: Path) -> bool:
    try:
        path.resolve().relative_to(REAL_AUDIO_DIR.resolve())
    except ValueError:
        return False
    return True


def _condition_measurement(
    condition: dict[str, Any],
    answer_trial: dict[str, Any],
    fixture: dict[str, Any],
    audio_root: Path,
    meter_cache: dict[str, dict[str, Any]],
    analysis_cli: Path | None,
) -> dict[str, Any]:
    relative_path = condition["audioFile"]
    audio_path = (REAL_AUDIO_DIR / relative_path).resolve()
    if not _inside_real_audio(audio_path) or not audio_path.is_file():
        raise AnalysisFailure(f"condition audio is missing or escapes pilot directory: {relative_path}")
    descriptor = parse_wav(audio_path)
    digest = sha256_file(audio_path)
    if digest != condition["sha256"]:
        raise AnalysisFailure(f"condition SHA-256 changed: {relative_path}")
    if digest not in meter_cache:
        meter_cache[digest] = measure(audio_path, analysis_cli)
    meter = meter_cache[digest]
    return {
        "trialRef": answer_trial["trialRef"],
        "trialLabel": answer_trial["trialLabel"],
        "conditionLabel": condition["conditionLabel"],
        "role": condition["role"],
        "fixtureIdentifier": answer_trial["fixtureIdentifier"],
        "processor": answer_trial["processor"],
        "audioFile": relative_path,
        "sha256": digest,
        "wav": descriptor,
        "bs1770": meter,
    }


def validate_pilot(
    analysis_cli: Path | None = DEFAULT_ANALYSIS_CLI,
    write_report: bool = True,
) -> dict[str, Any]:
    generation = load_json(GENERATION_REPORT_PATH)
    answer_key = load_json(ANSWER_KEY_PATH)
    participant = load_json(PARTICIPANT_MANIFEST_PATH)
    participant_template = load_json(PARTICIPANT_TEMPLATE_PATH)
    operator_template = load_json(OPERATOR_TEMPLATE_PATH)
    fixture_manifest = load_json(FIXTURE_MANIFEST_PATH)
    fixtures_by_id = {fixture["identifier"]: fixture for fixture in fixture_manifest["fixtures"]}

    for document, name in (
        (generation, "generation"),
        (answer_key, "answer key"),
        (participant, "participant manifest"),
        (participant_template, "participant template"),
        (operator_template, "operator template"),
    ):
        if document.get("pilotID") != PILOT_ID:
            raise AnalysisFailure(f"{name} has the wrong pilot ID")
        if document.get("evidenceClass") != EVIDENCE_CLASS:
            raise AnalysisFailure(f"{name} has the wrong evidence class")

    leaked = _assert_participant_boundary(participant, participant_template, fixture_manifest)
    if leaked:
        raise AnalysisFailure("participant identity leak: " + ", ".join(leaked[:10]))
    if answer_key.get("responses") != [] or operator_template.get("responses") != []:
        raise AnalysisFailure("operator response artifacts contain responses")
    if len(answer_key.get("trials", [])) != 6 or len(participant.get("trials", [])) != 6:
        raise AnalysisFailure("six-fixture pilot must contain exactly six trials")
    if generation.get("conditionCount") != 18:
        raise AnalysisFailure("six-fixture pilot must contain exactly eighteen condition files")
    if generation.get("participantResponses") != 0:
        raise AnalysisFailure("generation report has nonzero participant responses")

    participant_by_ref = {trial["trialRef"]: trial for trial in participant["trials"]}
    answer_by_ref = {trial["trialRef"]: trial for trial in answer_key["trials"]}
    if set(participant_by_ref) != set(answer_by_ref):
        raise AnalysisFailure("participant and answer-key trial references differ")

    generated_hashes = {
        (item["trialRef"], item["conditionLabel"]): item["sha256"] for item in generation["artifactHashes"]
    }
    meter_cache: dict[str, dict[str, Any]] = {}
    condition_rows: list[dict[str, Any]] = []
    trial_rows: list[dict[str, Any]] = []
    for trial_ref in sorted(answer_by_ref):
        answer_trial = answer_by_ref[trial_ref]
        fixture = fixtures_by_id.get(answer_trial["fixtureIdentifier"])
        if fixture is None:
            raise AnalysisFailure(f"answer key references unknown fixture: {answer_trial['fixtureIdentifier']}")
        participant_trial = participant_by_ref[trial_ref]
        participant_conditions = {condition["conditionLabel"]: condition for condition in participant_trial["conditions"]}
        measurements: list[dict[str, Any]] = []
        for condition in sorted(answer_trial["conditions"], key=lambda item: item["conditionLabel"]):
            participant_condition = participant_conditions.get(condition["conditionLabel"])
            if participant_condition is None or participant_condition["audioFile"] != condition["audioFile"]:
                raise AnalysisFailure(f"participant/answer audio mapping differs for {trial_ref}")
            expected_hash = generated_hashes.get((trial_ref, condition["conditionLabel"]))
            if expected_hash != condition["sha256"]:
                raise AnalysisFailure(f"generation report hash differs for {trial_ref} {condition['conditionLabel']}")
            row = _condition_measurement(condition, answer_trial, fixture, AUDIO_DIR, meter_cache, analysis_cli)
            measurements.append(row)
            condition_rows.append(row)
        by_role = {row["role"]: row for row in measurements}
        reference_lufs = by_role["reference"]["bs1770"]["integratedLoudnessLUFS"]
        target_lufs = by_role["target"]["bs1770"]["integratedLoudnessLUFS"]
        anchor_lufs = by_role["anchor"]["bs1770"]["integratedLoudnessLUFS"]
        if reference_lufs is None or target_lufs is None or anchor_lufs is None:
            level_status = "bounded_failure_no_finite_integrated_loudness"
            difference_lu = None
            anchor_difference_lu = None
        else:
            difference_lu = round(target_lufs - reference_lufs, 9)
            anchor_difference_lu = round(anchor_lufs - reference_lufs, 9)
            level_status = "pass" if abs(difference_lu) <= TOLERANCE_LU else "bounded_failure_target_outside_tolerance"
        peak_failures = []
        for row in measurements:
            true_peak = row["bs1770"]["truePeakDBTP"]
            if true_peak is None or true_peak > TRUE_PEAK_CEILING_DBTP:
                peak_failures.append(row["conditionLabel"])
        peak_status = "pass" if not peak_failures else "bounded_failure_true_peak_ceiling"
        trial_rows.append(
            {
                "trialRef": trial_ref,
                "trialLabel": answer_trial["trialLabel"],
                "fixtureIdentifier": answer_trial["fixtureIdentifier"],
                "conditions": measurements,
                "referenceIntegratedLoudnessLUFS": reference_lufs,
                "targetIntegratedLoudnessLUFS": target_lufs,
                "anchorIntegratedLoudnessLUFS": anchor_lufs,
                "targetMinusReferenceLU": difference_lu,
                "anchorMinusReferenceLU": anchor_difference_lu,
                "levelMatchToleranceLU": TOLERANCE_LU,
                "levelMatchStatus": level_status,
                "truePeakCeilingDBTP": TRUE_PEAK_CEILING_DBTP,
                "truePeakStatus": peak_status,
                "truePeakFailureLabels": peak_failures,
                "eligibleForLevelMatchedListening": level_status == "pass" and peak_status == "pass",
            }
        )

    bounded_failures = [
        trial["trialRef"]
        for trial in trial_rows
        if trial["levelMatchStatus"] != "pass" or trial["truePeakStatus"] != "pass"
    ]
    report = {
        "schemaVersion": "1.0",
        "pilotID": PILOT_ID,
        "evidenceClass": EVIDENCE_CLASS,
        "status": "verified_with_bounded_failures" if bounded_failures else "verified",
        "analysis": {
            "script": "analyze_real_audio.py",
            "engine": next(iter(meter_cache.values()))["meter"] if meter_cache else None,
            "uniqueAudioMeasured": len(meter_cache),
            "generatedAudioCount": len(condition_rows),
            "wavParseFailures": 0,
        },
        "levelMatch": {
            "method": "ITU-R BS.1770 integrated loudness",
            "toleranceLU": TOLERANCE_LU,
            "boundedFailureCount": len(bounded_failures),
            "boundedFailureTrialRefs": bounded_failures,
        },
        "truePeak": {
            "method": "ITU-R BS.1770 true peak meter",
            "ceilingDBTP": TRUE_PEAK_CEILING_DBTP,
        },
        "trials": trial_rows,
        "conditionMeasurements": condition_rows,
        "participantIdentityLeaks": len(leaked),
        "participantResponses": 0,
        "operatorResponses": 0,
        "claimBoundary": "Objective preparation evidence only. This six-fixture pilot does not render or close the original 24-excerpt natural-audio study and contains no perceptual-success claim.",
    }
    if write_report:
        write_json(ANALYSIS_REPORT_PATH, report)
        generation["status"] = "verified_pending_human_participation"
        generation["analysisReport"] = "real-audio-pilot-analysis.json"
        write_json(GENERATION_REPORT_PATH, generation)
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--analysis-cli", type=Path, default=DEFAULT_ANALYSIS_CLI)
    parser.add_argument("--no-write-report", action="store_true")
    args = parser.parse_args()
    try:
        report = validate_pilot(args.analysis_cli, write_report=not args.no_write_report)
    except (AnalysisFailure, FileNotFoundError, json.JSONDecodeError, ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"REAL_AUDIO_ANALYSIS_FAIL: {error}", file=sys.stderr)
        return 1
    print(
        "REAL_AUDIO_ANALYSIS_PASS "
        + json.dumps(
            {
                "pilotID": report["pilotID"],
                "status": report["status"],
                "generatedAudioCount": report["analysis"]["generatedAudioCount"],
                "uniqueAudioMeasured": report["analysis"]["uniqueAudioMeasured"],
                "boundedFailureCount": report["levelMatch"]["boundedFailureCount"],
                "participantIdentityLeaks": report["participantIdentityLeaks"],
                "participantResponses": report["participantResponses"],
            },
            sort_keys=True,
        )
    )
    for trial in report["trials"]:
        print(
            f"{trial['trialRef']} fixture={trial['fixtureIdentifier']} "
            f"target_minus_reference_lu={trial['targetMinusReferenceLU']} "
            f"level_match={trial['levelMatchStatus']} true_peak={trial['truePeakStatus']}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
