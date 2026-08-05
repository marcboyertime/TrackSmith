#!/usr/bin/env python3
"""Audit the generated G5 formative-study package without reading responses."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
import tempfile
from collections import Counter
from pathlib import Path
from typing import Any


PACKAGE_DIR = Path(__file__).resolve().parent
REPO_ROOT = PACKAGE_DIR.parents[3]
CORPUS_DIR = REPO_ROOT / "research/evaluation/production-mastery-v1/audio-evidence-corpus"
FIXTURE_DIR = REPO_ROOT / "research/evaluation/production-mastery-v1/dsp-listening-fixtures"
GENERATED_DIR = PACKAGE_DIR / "generated"
STUDY_ID = "tracksmith-g5-perceptual-study-v1"
EVIDENCE_CLASS = "SINGLE_LISTENER_FORMATIVE_EVIDENCE"
SOURCE_CLASSES = ("vocals", "drums", "bass", "guitars", "keys", "overall_mix")


def load_json(path: Path) -> Any:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def fail(message: str) -> None:
    raise AssertionError(message)


def assert_equal(actual: Any, expected: Any, message: str) -> None:
    if actual != expected:
        fail(f"{message}: expected {expected!r}, got {actual!r}")


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


def validate_participant_identity_boundary(participant: dict[str, Any], answer: dict[str, Any], source: dict[str, Any], fixture: dict[str, Any]) -> None:
    participant_strings = "\n".join(walk_strings(participant))
    forbidden: set[str] = set()
    for trial in answer["trials"]:
        forbidden.update(
            {
                trial["sourceAssetID"],
                trial["sourceArtifactSHA256"],
                trial["sourceCaptureSHA256"],
            }
        )
    for excerpt in source["naturalExcerpts"]:
        forbidden.update(
            {
                excerpt["assetID"],
                excerpt["memberPath"],
                excerpt["sourceCaptureID"],
                excerpt["sourceCaptureSHA256"],
            }
        )
    for item in fixture["fixtures"]:
        forbidden.add(item["identifier"])
        for key in ("sourceFixture",):
            forbidden.add(item[key])
        for artifact_key in ("sourceArtifact", "candidateArtifact", "planArtifact", "analysisArtifact"):
            forbidden.add(item[artifact_key]["path"])
            forbidden.add(item[artifact_key]["sha256"])
    leaked = sorted(token for token in forbidden if token and token in participant_strings)
    if leaked:
        fail("participant-facing manifest leaks operator identity: " + ", ".join(leaked[:5]))
    for trial in participant["trials"]:
        if not re.fullmatch(r"Trial [0-9]{3}", trial["trialLabel"]):
            fail(f"non-anonymous trial label: {trial['trialLabel']}")
        labels = [condition["conditionLabel"] for condition in trial["conditions"]]
        if labels != sorted(labels) and set(labels) != {"A", "B", "C"}:
            fail(f"condition labels are not exactly A/B/C: {labels}")
        if set(labels) != {"A", "B", "C"}:
            fail(f"condition labels are not distinct A/B/C: {labels}")
        for condition in trial["conditions"]:
            if not re.fullmatch(r"stimulus-[0-9]{3}-[ABC]", condition["artifactRef"]):
                fail(f"non-opaque artifact reference: {condition['artifactRef']}")


def validate_sources(source: dict[str, Any], corpus: dict[str, Any], fixture: dict[str, Any], fixture_manifest: dict[str, Any]) -> tuple[int, Counter[str]]:
    assert_equal(source["studyID"], STUDY_ID, "source study ID")
    assert_equal(len(source["naturalExcerpts"]), 24, "natural excerpt count")
    classes = Counter(excerpt["sourceClass"] for excerpt in source["naturalExcerpts"])
    assert_equal(classes, Counter({source_class: 4 for source_class in SOURCE_CLASSES}), "source class coverage")
    corpus_by_id = {asset["assetID"]: asset for asset in corpus["assets"]}
    for excerpt in source["naturalExcerpts"]:
        if excerpt["assetID"] not in corpus_by_id:
            fail(f"source absent from accepted corpus index: {excerpt['assetID']}")
        asset = corpus_by_id[excerpt["assetID"]]
        for key in ("artifactSHA256", "byteCount", "memberPath", "sourceCaptureSHA256", "sourceClass", "split"):
            assert_equal(excerpt[key], asset[key], f"source provenance {excerpt['assetID']} {key}")
        if not re.fullmatch(r"[0-9a-f]{64}", excerpt["artifactSHA256"]):
            fail(f"invalid source SHA-256: {excerpt['artifactSHA256']}")
        if not re.fullmatch(r"[0-9a-f]{64}", excerpt["sourceCaptureSHA256"]):
            fail(f"invalid source capture SHA-256: {excerpt['sourceCaptureSHA256']}")
        excerpt_data = excerpt["excerpt"]
        if excerpt_data["startSeconds"] < 0 or excerpt_data["endSeconds"] > asset["pcm"]["durationSeconds"] + 0.001:
            fail(f"excerpt window outside source duration: {excerpt['assetID']}")
    fixture_by_id = {item["identifier"]: item for item in fixture_manifest["fixtures"]}
    assert_equal(len(source["dspFixtures"]), len(fixture_manifest["fixtures"]), "fixture count")
    for item in source["dspFixtures"]:
        if item["identifier"] not in fixture_by_id:
            fail(f"fixture absent from accepted fixture manifest: {item['identifier']}")
        expected = fixture_by_id[item["identifier"]]
        for key in ("sourceInputSHA256", "sourceInputUnchanged", "sourceFixture", "processor"):
            assert_equal(item[key], expected[key], f"fixture provenance {item['identifier']} {key}")
        for artifact_key in ("sourceArtifact", "candidateArtifact", "planArtifact", "analysisArtifact"):
            assert_equal(item[artifact_key], expected[artifact_key], f"fixture provenance {item['identifier']} {artifact_key}")
    return len(source["naturalExcerpts"]), classes


def validate_package(package_dir: Path, check_deterministic: bool) -> dict[str, Any]:
    protocol = load_json(package_dir / "protocol.json")
    source = load_json(package_dir / "source-manifest.json")
    participant = load_json(package_dir / "generated/participant-manifest.json")
    answer = load_json(package_dir / "generated/answer-key.json")
    level_match = load_json(package_dir / "generated/level-match-metadata.json")
    study = load_json(package_dir / "generated/study-manifest.json")
    corpus = load_json(CORPUS_DIR / "natural-audio-index.json")
    fixture_manifest = load_json(FIXTURE_DIR / "manifest.json")

    for document, name in ((protocol, "protocol"), (source, "source"), (participant, "participant"), (answer, "answer"), (level_match, "level-match"), (study, "study")):
        assert_equal(document["studyID"], STUDY_ID, f"{name} study ID")
        assert_equal(document["evidenceClass"], EVIDENCE_CLASS, f"{name} evidence class")
    assert_equal(protocol["status"], "prepared_pending_human_participation", "protocol status")
    assert_equal(protocol["mushra"]["claimed"], False, "MUSHRA claim boundary")
    assert_equal(participant["participantFacing"], True, "participant-facing flag")
    assert_equal(participant["responses"], [], "participant response absence")
    assert_equal(answer["responses"], [], "answer-key response absence")
    assert_equal(study["participantResponses"], 0, "study response count")
    assert_equal(len(participant["trials"]), 28, "presentation trial count")
    assert_equal(len(answer["trials"]), 28, "answer trial count")
    assert_equal(len(participant["questions"]), 8, "question count")
    question_ids = [question["id"] for question in participant["questions"]]
    assert_equal(
        question_ids,
        ["target_success", "preservation", "naturalness", "clarity", "production_value", "excitement", "preference", "confidence"],
        "question dimensions",
    )
    validate_participant_identity_boundary(participant, answer, source, fixture_manifest)
    source_count, classes = validate_sources(source, corpus, fixture_manifest, fixture_manifest)

    participant_refs = {trial["trialRef"] for trial in participant["trials"]}
    answer_refs = {trial["trialRef"] for trial in answer["trials"]}
    assert_equal(participant_refs, answer_refs, "participant/answer trial refs")
    duplicate_trials = [trial for trial in answer["trials"] if trial["hiddenDuplicateOf"]]
    assert_equal(len(duplicate_trials), 4, "hidden duplicate count")
    if not all(trial["hiddenDuplicateOf"] in answer_refs for trial in duplicate_trials):
        fail("hidden duplicate points to unknown trial")
    anchor_count = sum(
        sum(condition["role"] == "anchor" for condition in trial["conditions"])
        for trial in answer["trials"]
    )
    assert_equal(anchor_count, 28, "hidden anchor count")
    for trial in answer["trials"]:
        roles = {condition["role"] for condition in trial["conditions"]}
        assert_equal(roles, {"reference", "target", "anchor"}, f"condition roles for {trial['trialRef']}")
    methods = {condition["levelMatch"]["method"] for trial in participant["trials"] for condition in trial["conditions"]}
    assert_equal(methods, {"bs1770Integrated"}, "participant level-match method")
    if level_match["status"] != "metadata_prepared_no_real_audio_condition_render":
        fail("level-match metadata must remain pending until real-audio renders exist")
    if any(value not in (None, 0.0) for trial in level_match["naturalExcerptConditions"] for value in [condition["gainDB"] for condition in trial["conditions"]]):
        fail("natural condition gain must not be invented")

    if check_deterministic:
        generator = package_dir / "generate_study.py"
        with tempfile.TemporaryDirectory(prefix="tracksmith-g5-determinism-") as temporary:
            temporary_dir = Path(temporary)
            output_dir = temporary_dir / "generated"
            source_path = temporary_dir / "source-manifest.json"
            subprocess.run(
                [sys.executable, str(generator), "--output-dir", str(output_dir), "--source-manifest", str(source_path)],
                check=True,
                cwd=package_dir,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            pairs = [
                (package_dir / "protocol.json", temporary_dir / "protocol.json"),
                (package_dir / "source-manifest.json", source_path),
                (package_dir / "generated/participant-manifest.json", output_dir / "participant-manifest.json"),
                (package_dir / "generated/answer-key.json", output_dir / "answer-key.json"),
                (package_dir / "generated/level-match-metadata.json", output_dir / "level-match-metadata.json"),
                (package_dir / "generated/study-manifest.json", output_dir / "study-manifest.json"),
            ]
            for expected, generated in pairs:
                assert_equal(generated.read_bytes(), expected.read_bytes(), f"deterministic artifact {expected.name}")

    return {
        "status": "pass",
        "studyID": STUDY_ID,
        "evidenceClass": EVIDENCE_CLASS,
        "uniqueNaturalExcerpts": source_count,
        "sourceClasses": dict(sorted(classes.items())),
        "presentationTrials": len(participant["trials"]),
        "hiddenDuplicates": len(duplicate_trials),
        "hiddenAnchors": anchor_count,
        "participantResponses": 0,
        "renderStatus": level_match["status"],
        "participantIdentityLeaks": 0,
        "deterministic": check_deterministic,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package-dir", type=Path, default=PACKAGE_DIR)
    parser.add_argument("--no-deterministic-check", action="store_true")
    parser.add_argument("--write-report", action="store_true")
    args = parser.parse_args()
    try:
        report = validate_package(args.package_dir, check_deterministic=not args.no_deterministic_check)
    except (AssertionError, FileNotFoundError, json.JSONDecodeError) as error:
        print(f"ANALYSIS_FAIL: {error}", file=sys.stderr)
        return 1
    if args.write_report:
        report_path = args.package_dir / "generated/analysis-report.json"
        report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("ANALYSIS_PASS " + json.dumps(report, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
