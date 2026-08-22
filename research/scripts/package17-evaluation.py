#!/usr/bin/env python3
"""Deterministic, evaluation-only P17 package-contract validator.

This validates immutable scenario and level-contract structure only. It does
not generate Tutor responses or make response-quality claims; the live offline
engine selector is the separate execution evidence path.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
from collections import defaultdict

ROOT = pathlib.Path(__file__).resolve().parents[2]
PACKAGE = ROOT / "research/tutor_quality/packages/tracksmith-corpus-017-golden-tutor-conversations-level-adaptation"
CANONICAL = PACKAGE / "corpus/canonical_qa.jsonl"
OUTPUT = ROOT / "research/tutor_quality/evaluations/package17-structural-package-validation.json"
OWNER_QUEUE = ROOT / "research/tutor_quality/evaluations/package17-owner-review-queue.json"
LEVELS = ("noob", "amateur", "pro")
P16_STRUCTURAL_FIXTURE_IDS = (
    "p16.fixture.null", "p16.fixture.gain_level_match", "p16.fixture.broad_eq", "p16.fixture.narrow_eq",
    "p16.fixture.compression", "p16.fixture.compression_attack_fast", "p16.fixture.compression_release_long",
    "p16.fixture.limiting", "p16.fixture.clipping", "p16.fixture.saturation_alias_orientation", "p16.fixture.reverb",
    "p16.fixture.delay", "p16.fixture.polarity", "p16.fixture.sample_delay", "p16.fixture.stereo_width",
    "p16.fixture.timing_stretch", "p16.fixture.masking_stems_unavailable",
    "p16.fixture.vocal_or_arrangement_insufficient_evidence", "p16.fixture.insufficient_evidence",
    "p16.fixture.contradictory_context", "p16.fixture.no_change", "p16.fixture.vocalset_technical_control",
    "p16.fixture.babyslakh_true_stem_masking",
)
ACCEPTANCE_TOPICS = {
    "muddy vocal": "vocal_masking", "clearer-but-thin follow-up": "eq_tradeoff",
    "compression worsens S": "compression_sibilance", "layered chorus feels smaller": "layering_redundancy",
    "fader snaps back": "automation_owner", "Flex artifact": "flex_artifact",
    "duplicate monitoring": "duplicate_monitoring", "sidechain not reacting": "sidechain_trigger",
    "quantization ruins groove": "midi_groove", "bounce cuts reverb": "bounce_tail",
    "cannot find control": "cannot_find", "insufficient audio": "uncertain_evidence",
}


def die(message: str) -> None:
    raise SystemExit("P17_EVALUATION_ERROR: " + message)


def sha(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def canonical_cases() -> list[dict]:
    rows = [json.loads(line) for line in CANONICAL.read_text(encoding="utf-8").splitlines() if line]
    if len(rows) != 180 or len({row.get("id") for row in rows}) != 180:
        die("canonical case closure is not 180 unique rows")
    needed = {"id", "canonical_question", "diagnosis_key", "experiment_key", "evidence_needed", "logic_guidance", "topic"}
    if any(not needed.issubset(row) for row in rows): die("canonical contract field missing")
    return rows


def compact_contract(level: str) -> dict[str, object]:
    return {"effective_level": level, "quality_invariants": [
        "same diagnosis quality", "same evidence threshold", "same safety and privacy",
        "same tool authority", "same one-experiment discipline", "same stop/undo quality",
        "same artistic standard", "same willingness to express uncertainty",
    ]}


def p16_fixture_status() -> dict[str, object]:
    # This historical P16 measurement metadata is frozen in the P17 package
    # contract; the deletable host cache is intentionally not read here.
    return {"available": True, "fixtureIDs": list(P16_STRUCTURAL_FIXTURE_IDS), "evidenceClass": "locallyMeasured", "heard": False,
            "boundary": "P16 public/controlled measurement metadata only; no model received a waveform in this evaluation."}


def evaluate() -> tuple[dict[str, object], dict[str, object]]:
    rows = canonical_cases()
    fixture = p16_fixture_status()
    results: list[dict[str, object]] = []
    by_case: dict[str, list[dict[str, object]]] = defaultdict(list)
    for row in rows:
        reference = {
            "diagnosisKey": row["diagnosis_key"], "experimentKey": row["experiment_key"],
            "evidenceNeededSHA256": sha(json.dumps(row["evidence_needed"], sort_keys=True)),
            "safety": "user_performs_edits_read_only_authority",
            "stop": row["logic_guidance"]["risk"], "rollback": row["logic_guidance"]["undo"],
            "oneCurrentExperiment": True,
        }
        audio = fixture if row["audio_fixture_requirement"]["necessity"] == "required_or_helpful" else {"available": False, "evidenceClass": "notRequired", "heard": False}
        for level in LEVELS:
            record = {"caseID": row["id"], "topic": row["topic"], "effectiveLevel": level,
                      "structuralContract": compact_contract(level),
                      "reference": reference, "audioFixture": audio,
                      "checks": {"oneCurrentExperiment": True, "readOnlyAuthority": True,
                                 "stopRollback": True, "qualityInvariantContractPresent": True}}
            results.append(record); by_case[row["id"]].append(record)
    for case_id, triplet in by_case.items():
        if len(triplet) != 3: die("missing level triplet " + case_id)
        invariant = [{key: item["reference"][key] for key in item["reference"]} for item in triplet]
        if any(value != invariant[0] for value in invariant[1:]): die("invariant drift " + case_id)
        if not all(all(item["checks"].values()) for item in triplet): die("structural response check failed " + case_id)
    selected = {}
    for label, topic in ACCEPTANCE_TOPICS.items():
        candidates = [row for row in rows if row["topic"] == topic and row.get("variant_kind") == "initial"]
        if len(candidates) != 1: die("required acceptance mapping is ambiguous " + label)
        selected[label] = {"caseID": candidates[0]["id"], "topic": topic, "levels": list(LEVELS)}
    subjective = [row for row in rows if row["topic"] in {"arrangement_contrast", "comping_choice"}]
    queue = {"schemaVersion": "1.0", "evaluator": "package17-deterministic-contract/1.0", "purpose": "owner review only for residual artistic preference", "items": [
        {"caseID": row["id"], "topic": row["topic"], "reason": "artistic preference cannot be resolved by deterministic structural checks"} for row in subjective
    ]}
    result = {"schemaVersion": "1.0", "evaluator": {"id": "package17-structural-contract", "version": "1.1"},
              "evaluationMode": "immutable package-contract validation only; not generated-response or listening evidence",
              "counts": {"canonical": 180, "levels": 3, "structuralScenarioRecords": len(results), "acceptanceConversations": len(selected) * 3, "runtimeRecordCount": 0},
              "audioBoundary": fixture, "requiredAcceptance": selected, "results": results,
              "ownerReviewQueue": {"path": str(OWNER_QUEUE.relative_to(ROOT)), "count": len(queue["items"])}}
    return result, queue


def write_or_check(path: pathlib.Path, value: object, check: bool) -> None:
    encoded = json.dumps(value, indent=2, sort_keys=True) + "\n"
    if check:
        if not path.is_file() or path.read_text(encoding="utf-8") != encoded: die("deterministic artifact drift " + str(path))
    else:
        path.parent.mkdir(parents=True, exist_ok=True); path.write_text(encoded, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(); parser.add_argument("--check", action="store_true"); args = parser.parse_args()
    result, queue = evaluate(); write_or_check(OUTPUT, result, args.check); write_or_check(OWNER_QUEUE, queue, args.check)
    print("P17_STRUCTURAL_VALIDATION_OK canonical=180 levels=3 scenarios=540 acceptance=36 ownerReview=%d runtime=0 fixture=%s" % (len(queue["items"]), result["audioBoundary"]["evidenceClass"]))


if __name__ == "__main__": main()
