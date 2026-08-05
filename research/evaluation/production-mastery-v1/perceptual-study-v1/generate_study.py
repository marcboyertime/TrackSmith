#!/usr/bin/env python3
"""Build the TrackSmith G5 blinded formative-study package.

The generator only reads the checked-in corpus indexes and DSP fixture manifest.
It never downloads, copies, or renders audio.  The participant manifest contains
opaque labels; the operator answer key retains the identity needed to prepare a
future real-audio session.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import random
import re
from pathlib import Path
from typing import Any, Iterable


PACKAGE_DIR = Path(__file__).resolve().parent
REPO_ROOT = PACKAGE_DIR.parents[3]
CORPUS_DIR = REPO_ROOT / "research/evaluation/production-mastery-v1/audio-evidence-corpus"
FIXTURE_DIR = REPO_ROOT / "research/evaluation/production-mastery-v1/dsp-listening-fixtures"
DEFAULT_OUTPUT_DIR = PACKAGE_DIR / "generated"
DEFAULT_SOURCE_MANIFEST = PACKAGE_DIR / "source-manifest.json"
DEFAULT_SEED = 20260802
SCHEMA_VERSION = "1.0"
STUDY_ID = "tracksmith-g5-perceptual-study-v1"
EVIDENCE_CLASS = "SINGLE_LISTENER_FORMATIVE_EVIDENCE"
SOURCE_CLASSES = ("vocals", "drums", "bass", "guitars", "keys", "overall_mix")
EXCERPTS_PER_CLASS = 4
HIDDEN_DUPLICATE_COUNT = 4


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def load_json(path: Path) -> Any:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def canonical_json(value: Any) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")


def source_record(index: dict[str, Any], asset_id: str) -> dict[str, Any]:
    for asset in index["assets"]:
        if asset["assetID"] == asset_id:
            return asset
    raise KeyError(f"asset not found in natural-audio-index.json: {asset_id}")


def select_assets(index: dict[str, Any]) -> list[dict[str, Any]]:
    """Select four indexed assets per required class without changing corpus data."""

    selected: list[dict[str, Any]] = []
    for source_class in SOURCE_CLASSES:
        pool = [
            asset
            for asset in index["assets"]
            if asset.get("datasetID") == "mixassist"
            and asset.get("sourceClass") == source_class
        ]
        if len(pool) < EXCERPTS_PER_CLASS:
            raise ValueError(f"not enough accepted assets for {source_class}")
        pool.sort(key=lambda asset: asset["assetID"])
        holdout = [asset for asset in pool if asset.get("split") == "tracksmith_holdout"]
        evaluation = [asset for asset in pool if asset.get("split") == "evaluation"]
        # Keep a holdout/evaluation mix where the accepted index makes that possible.
        if len(holdout) >= 2 and len(evaluation) >= 2:
            chosen = holdout[:2] + evaluation[:2]
        else:
            chosen = pool[:EXCERPTS_PER_CLASS]
        chosen.sort(key=lambda asset: asset["assetID"])
        selected.extend(chosen)
    if len(selected) != len(SOURCE_CLASSES) * EXCERPTS_PER_CLASS:
        raise AssertionError("selection count drift")
    return selected


def excerpt_window(asset: dict[str, Any], ordinal: int) -> dict[str, float | str]:
    duration = float(asset["pcm"]["durationSeconds"])
    requested = 8.0
    maximum_start = max(0.0, duration - min(requested, duration))
    # This is provenance for a future render, not a rewritten audio payload.
    start = round((ordinal * 1.37) % (maximum_start + 1.0), 3) if maximum_start else 0.0
    excerpt_duration = round(min(requested, duration - start), 3)
    return {
        "selectionMethod": "deterministic_window_no_audio_rewrite",
        "startSeconds": start,
        "durationSeconds": excerpt_duration,
        "endSeconds": round(start + excerpt_duration, 3),
    }


def fixture_identity(manifest: dict[str, Any]) -> list[dict[str, Any]]:
    fixtures: list[dict[str, Any]] = []
    for fixture in sorted(manifest["fixtures"], key=lambda item: item["identifier"]):
        fixtures.append(
            {
                "identifier": fixture["identifier"],
                "processor": fixture["processor"],
                "status": fixture["status"],
                "sourceFixture": fixture["sourceFixture"],
                "sourceInputSHA256": fixture["sourceInputSHA256"],
                "sourceInputUnchanged": fixture["sourceInputUnchanged"],
                "sourceArtifact": fixture["sourceArtifact"],
                "candidateArtifact": fixture["candidateArtifact"],
                "planArtifact": fixture["planArtifact"],
                "analysisArtifact": fixture["analysisArtifact"],
                "loudnessMatch": {
                    "method": fixture["loudnessMatchMethod"],
                    "gainDB": fixture["loudnessMatchGainDB"],
                    "difference": fixture["difference"],
                },
                "preservationBoundary": fixture["preservationBoundary"],
                "intendedComparison": fixture["intendedComparison"],
                "subjectivePreferenceRecorded": fixture["subjectivePreferenceRecorded"],
            }
        )
    return fixtures


def source_manifest(
    corpus_index: dict[str, Any],
    fixture_manifest: dict[str, Any],
    selected: list[dict[str, Any]],
    seed: int,
) -> dict[str, Any]:
    excerpts: list[dict[str, Any]] = []
    for ordinal, asset in enumerate(selected, start=1):
        excerpts.append(
            {
                "sourceOrdinal": ordinal,
                "assetID": asset["assetID"],
                "datasetID": asset["datasetID"],
                "sourceClass": asset["sourceClass"],
                "role": asset["role"],
                "split": asset["split"],
                "memberPath": asset["memberPath"],
                "artifactSHA256": asset["artifactSHA256"],
                "byteCount": asset["byteCount"],
                "sourceCaptureID": asset["sourceCaptureID"],
                "sourceCaptureSHA256": asset["sourceCaptureSHA256"],
                "pcm": asset["pcm"],
                "excerpt": excerpt_window(asset, ordinal),
                "rightsBoundary": "local_evaluation_only; no redistribution or provider upload",
            }
        )
    return {
        "schemaVersion": SCHEMA_VERSION,
        "studyID": STUDY_ID,
        "evidenceClass": EVIDENCE_CLASS,
        "purpose": "operator provenance for a prepared, not-yet-run formative study",
        "selection": {
            "requiredSourceClasses": list(SOURCE_CLASSES),
            "excerptsPerClass": EXCERPTS_PER_CLASS,
            "uniqueNaturalExcerpts": len(excerpts),
            "selectionSeed": seed,
            "selectionSource": "accepted natural-audio-index.json; no download or audio rewrite",
        },
        "inputs": {
            "naturalAudioIndex": {
                "path": "research/evaluation/production-mastery-v1/audio-evidence-corpus/natural-audio-index.json",
                "sha256": sha256_file(CORPUS_DIR / "natural-audio-index.json"),
            },
            "dspFixtureManifest": {
                "path": "research/evaluation/production-mastery-v1/dsp-listening-fixtures/manifest.json",
                "sha256": sha256_file(FIXTURE_DIR / "manifest.json"),
            },
        },
        "naturalExcerpts": excerpts,
        "dspFixtures": fixture_identity(fixture_manifest),
        "claimBoundary": {
            "datasetLabelsArePreference": False,
            "dspFixturesAreHumanEvidence": False,
            "naturalAudioHasNoInventedResponses": True,
            "candidateIdentitiesAreParticipantHidden": True,
            "mushraClaim": False,
        },
    }


def questions() -> list[dict[str, Any]]:
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


def protocol_document(seed: int) -> dict[str, Any]:
    return {
        "schemaVersion": SCHEMA_VERSION,
        "studyID": STUDY_ID,
        "milestone": "G5",
        "status": "prepared_pending_human_participation",
        "evidenceClass": EVIDENCE_CLASS,
        "title": "TrackSmith single-listener formative A/B/C study",
        "objective": "Evaluate target success and preservation on accepted natural-audio excerpts after real-audio condition renders are prepared.",
        "protocolType": "randomized_blinded_level_matched_ABC_formative",
        "mushra": {
            "claimed": False,
            "reason": "This package does not assert the hidden-reference, anchor, training, reproduction, power, or statistical requirements for MUSHRA.",
        },
        "stimulusPlan": {
            "uniqueNaturalExcerpts": len(SOURCE_CLASSES) * EXCERPTS_PER_CLASS,
            "sourceClasses": list(SOURCE_CLASSES),
            "excerptsPerClass": EXCERPTS_PER_CLASS,
            "conditionsPerTrial": 3,
            "conditionRoles": ["reference", "target", "anchor"],
            "hiddenDuplicatePresentations": HIDDEN_DUPLICATE_COUNT,
            "differentDayRepeatPolicy": "Repeat the designated hidden duplicate on a separate listening day when possible.",
            "renderStatus": "pending_real_audio_condition_renders",
            "renderBoundary": "No new audio is generated by this package; the answer key only points to accepted source identities and existing fixture metadata.",
        },
        "levelMatching": {
            "method": "ITU-R BS.1770 integrated loudness where a render exists",
            "fixtureMethodToken": "bs1770Integrated",
            "targetToleranceLU": 0.5,
            "truePeakCeilingDBTP": -1.0,
            "tailPolicy": "Keep the same excerpt window and document any rendered tail separately.",
            "missingRenderStatus": "not_run",
        },
        "randomization": {
            "seed": seed,
            "algorithm": "Python random.Random(seed) shuffle; seed is retained in the operator answer key",
            "participantLabels": "Trial NNN and A/B/C only",
            "identityDisclosure": "Candidate, fixture, dataset, and source names stay outside participant-facing labels.",
        },
        "monitoring": {
            "requiredContext": "Document listener, room/headphone path, interface, sample rate, bit depth, playback level, and date before participation.",
            "levelBiasControl": "Use synchronized looping and matched playback gain; never ask preference on raw-loudness differences.",
        },
        "training": {
            "requiredBeforeJudgment": True,
            "useOnlyNonScoredExamples": True,
            "doNotRevealIdentities": True,
        },
        "questions": questions(),
        "responsePolicy": {
            "participantCount": 0,
            "responsesCollected": False,
            "responsesInvented": False,
            "g5Status": "pending_until_user_participates",
            "analysisRequires": [
                "raw_response_export",
                "predeclared_exclusions",
                "medians_and_IQRs",
                "effect_sizes_and_intervals_when_justified",
                "corrected_pairwise_comparisons_only_if_appropriate",
            ],
        },
        "claimBoundary": {
            "noPerceptualSuccessClaim": True,
            "noUniversalProductionTruth": True,
            "singleListenerIsNotPopulationEvidence": True,
            "syntheticFixtureMetricsAreNotHumanResponses": True,
        },
    }


def anonymous_token(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9_-]", "-", value)


def build_artifacts(seed: int = DEFAULT_SEED) -> dict[str, Any]:
    corpus_index = load_json(CORPUS_DIR / "natural-audio-index.json")
    fixture_manifest = load_json(FIXTURE_DIR / "manifest.json")
    protocol = protocol_document(seed)
    selected = select_assets(corpus_index)
    provenance = source_manifest(corpus_index, fixture_manifest, selected, seed)

    # The condition role is intentionally only in the operator answer key.  A
    # participant sees no source/fixture/candidate identity or role names.
    rng = random.Random(seed)
    trials: list[dict[str, Any]] = []
    answers: list[dict[str, Any]] = []
    for ordinal, source in enumerate(selected, start=1):
        trial_id = f"trial-{ordinal:03d}"
        role_labels = ["reference", "target", "anchor"]
        rng.shuffle(role_labels)
        condition_order = ["A", "B", "C"]
        rng.shuffle(condition_order)
        condition_rows = []
        answer_conditions = []
        for label, role in zip(condition_order, role_labels):
            ref = f"stimulus-{ordinal:03d}-{label}"
            condition_rows.append(
                {
                    "conditionLabel": label,
                    "artifactRef": ref,
                    "levelMatch": {
                        "method": "bs1770Integrated",
                        "target": "same_integrated_loudness_as_reference",
                        "toleranceLU": 0.5,
                        "gainDB": None,
                        "status": "pending_real_audio_condition_render",
                    },
                }
            )
            answer_conditions.append(
                {
                    "conditionLabel": label,
                    "role": role,
                    "artifactRef": ref,
                    "renderStatus": "not_provided",
                }
            )
        trials.append(
            {
                "trialLabel": f"Trial {ordinal:03d}",
                "trialRef": trial_id,
                "conditions": condition_rows,
            }
        )
        answers.append(
            {
                "trialRef": trial_id,
                "trialLabel": f"Trial {ordinal:03d}",
                "sourceOrdinal": ordinal,
                "sourceAssetID": source["assetID"],
                "sourceArtifactSHA256": source["artifactSHA256"],
                "sourceCaptureSHA256": source["sourceCaptureSHA256"],
                "sourceClass": source["sourceClass"],
                "excerpt": excerpt_window(source, ordinal),
                "conditions": answer_conditions,
                "hiddenDuplicateOf": None,
                "isAnchorPresentation": False,
            }
        )

    # Add concealed duplicate presentations. They reuse the exact source hash,
    # but get a new participant-facing trial label and a fresh randomized order.
    duplicate_ordinals = [1, 7, 13, 19]
    for duplicate_number, source_ordinal in enumerate(duplicate_ordinals, start=1):
        original = answers[source_ordinal - 1]
        trial_number = len(trials) + 1
        trial_id = f"trial-{trial_number:03d}"
        role_labels = ["reference", "target", "anchor"]
        rng.shuffle(role_labels)
        condition_order = ["A", "B", "C"]
        rng.shuffle(condition_order)
        conditions = []
        answer_conditions = []
        for label, role in zip(condition_order, role_labels):
            ref = f"stimulus-{trial_number:03d}-{label}"
            conditions.append(
                {
                    "conditionLabel": label,
                    "artifactRef": ref,
                    "levelMatch": {
                        "method": "bs1770Integrated",
                        "target": "same_integrated_loudness_as_reference",
                        "toleranceLU": 0.5,
                        "gainDB": None,
                        "status": "pending_real_audio_condition_render",
                    },
                }
            )
            answer_conditions.append(
                {
                    "conditionLabel": label,
                    "role": role,
                    "artifactRef": ref,
                    "renderStatus": "not_provided",
                }
            )
        trials.append(
            {
                "trialLabel": f"Trial {trial_number:03d}",
                "trialRef": trial_id,
                "conditions": conditions,
            }
        )
        answers.append(
            {
                "trialRef": trial_id,
                "trialLabel": f"Trial {trial_number:03d}",
                "sourceOrdinal": source_ordinal,
                "sourceAssetID": original["sourceAssetID"],
                "sourceArtifactSHA256": original["sourceArtifactSHA256"],
                "sourceCaptureSHA256": original["sourceCaptureSHA256"],
                "sourceClass": original["sourceClass"],
                "excerpt": original["excerpt"],
                "conditions": answer_conditions,
                "hiddenDuplicateOf": original["trialRef"],
                "isAnchorPresentation": False,
            }
        )

    # Shuffle the presentation order after duplicate construction. The answer
    # key keeps the mapping by trialRef, while labels remain anonymous.
    rng.shuffle(trials)
    rng.shuffle(answers)
    answer_by_ref = {answer["trialRef"]: answer for answer in answers}
    participant_manifest = {
        "schemaVersion": SCHEMA_VERSION,
        "studyID": STUDY_ID,
        "evidenceClass": EVIDENCE_CLASS,
        "status": "prepared_pending_human_participation",
        "participantFacing": True,
        "identityDisclosure": "none",
        "randomizationSeedStoredIn": "answer-key.json",
        "trialCount": len(trials),
        "uniqueNaturalExcerptCount": len(selected),
        "conditionsPerTrial": 3,
        "questions": questions(),
        "monitoringPrompt": "Record monitoring context separately before listening; do not enter participant identity here.",
        "trials": trials,
        "responses": [],
    }

    answer_key = {
        "schemaVersion": SCHEMA_VERSION,
        "studyID": STUDY_ID,
        "evidenceClass": EVIDENCE_CLASS,
        "operatorOnly": True,
        "randomizationSeed": seed,
        "randomizationAlgorithm": "Python random.Random(seed) shuffle",
        "sourceManifest": "../source-manifest.json",
        "participantManifest": "participant-manifest.json",
        "candidateIdentitiesAreHiddenUntilJudgment": True,
        "fixturesAreStimulusMetadataOnly": True,
        "trials": answers,
        "responses": [],
    }

    level_match = {
        "schemaVersion": SCHEMA_VERSION,
        "studyID": STUDY_ID,
        "evidenceClass": EVIDENCE_CLASS,
        "method": "ITU-R BS.1770 integrated loudness (fixture token: bs1770Integrated)",
        "targetToleranceLU": 0.5,
        "truePeakCeilingDBTP": -1.0,
        "status": "metadata_prepared_no_real_audio_condition_render",
        "naturalExcerptConditions": [
            {
                "trialRef": answer["trialRef"],
                "sourceArtifactSHA256": answer["sourceArtifactSHA256"],
                "conditions": [
                    {
                        "conditionLabel": condition["conditionLabel"],
                        "role": condition["role"],
                        "gainDB": None,
                        "measurementStatus": "pending_render",
                    }
                    for condition in answer["conditions"]
                ],
            }
            for answer in sorted(answers, key=lambda item: item["trialRef"])
        ],
        "existingFixtureMatches": [
            {
                "identifier": fixture["identifier"],
                "sourceSHA256": fixture["sourceArtifact"]["sha256"],
                "candidateSHA256": fixture["candidateArtifact"]["sha256"],
                "method": fixture["loudnessMatch"]["method"],
                "gainDB": fixture["loudnessMatch"]["gainDB"],
            }
            for fixture in provenance["dspFixtures"]
        ],
    }

    return {
        "protocol": protocol,
        "sourceManifest": provenance,
        "participantManifest": participant_manifest,
        "answerKey": answer_key,
        "levelMatch": level_match,
    }


def write_artifacts(output_dir: Path, source_path: Path, seed: int) -> dict[str, Path]:
    artifacts = build_artifacts(seed)
    output_dir.mkdir(parents=True, exist_ok=True)
    source_path.parent.mkdir(parents=True, exist_ok=True)
    protocol_path = output_dir.parent / "protocol.json"
    write_json(source_path, artifacts["sourceManifest"])
    write_json(protocol_path, artifacts["protocol"])
    paths = {
        "protocol": protocol_path,
        "sourceManifest": source_path,
        "participantManifest": output_dir / "participant-manifest.json",
        "answerKey": output_dir / "answer-key.json",
        "levelMatch": output_dir / "level-match-metadata.json",
    }
    write_json(paths["participantManifest"], artifacts["participantManifest"])
    write_json(paths["answerKey"], artifacts["answerKey"])
    write_json(paths["levelMatch"], artifacts["levelMatch"])
    study_manifest = {
        "schemaVersion": SCHEMA_VERSION,
        "studyID": STUDY_ID,
        "evidenceClass": EVIDENCE_CLASS,
        "status": "prepared_pending_human_participation",
        "randomizationSeed": seed,
        "uniqueNaturalExcerptCount": len(artifacts["sourceManifest"]["naturalExcerpts"]),
        "trialCount": len(artifacts["participantManifest"]["trials"]),
        "hiddenDuplicateCount": sum(
            answer["hiddenDuplicateOf"] is not None for answer in artifacts["answerKey"]["trials"]
        ),
        "hiddenAnchorCount": sum(
            any(condition["role"] == "anchor" for condition in answer["conditions"])
            for answer in artifacts["answerKey"]["trials"]
        ),
        "participantResponses": 0,
        "claimBoundary": "Preparation metadata only; no human response or perceptual-success claim.",
        "files": {
            "protocol": "../protocol.json",
            "sourceManifest": "../source-manifest.json",
            "participantManifest": "participant-manifest.json",
            "answerKey": "answer-key.json",
            "levelMatchMetadata": "level-match-metadata.json",
        },
    }
    paths["studyManifest"] = output_dir / "study-manifest.json"
    write_json(paths["studyManifest"], study_manifest)
    return paths


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=int, default=DEFAULT_SEED)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--source-manifest", type=Path, default=DEFAULT_SOURCE_MANIFEST)
    args = parser.parse_args()
    paths = write_artifacts(args.output_dir, args.source_manifest, args.seed)
    print(f"generated study={STUDY_ID} seed={args.seed}")
    print(f"unique_natural_excerpts={len(build_artifacts(args.seed)['sourceManifest']['naturalExcerpts'])}")
    print(f"presentation_trials={len(load_json(paths['participantManifest'])['trials'])}")
    print("participant_responses=0")
    for label, path in sorted(paths.items()):
        print(f"{label}={path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
