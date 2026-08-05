#!/usr/bin/env python3
"""Fail-closed audit of the reviewed tutor procedure artifact.

Mirrors the rules enforced at runtime by TutorKnowledgeValidator so a review
problem is caught at authoring time. Exits nonzero on the first violation.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
DEFAULT_INPUT = ROOT / "research/knowledge/logic-pro-12.3-tutor-procedures.json"
EXPECTED_SCHEMA = "tracksmith.logic-tutor-procedures.v1"

VALID_SOURCE_TYPES = {
    "vocal", "vocalBus", "drums", "drumBus", "bass", "guitar", "keyboard",
    "synth", "fullMix", "reference", "unknown",
}
VALID_ISSUES = {
    "nasalOrHonky", "congested", "boxy", "muddy", "harsh", "sibilant", "thin",
    "boomy", "dull", "inconsistentLevel", "overcompressed", "tooDry", "tooWet",
    "tooDistant", "noisyBetweenPhrases", "plosive", "clippingOrOverload",
    "unclearOrBuried",
}
VALID_CAUSES = {
    "performanceOrVowelFormation", "microphonePositionOrCapture",
    "roomOrReflection", "existingProcessing", "staticSpectralResonance",
    "timeVaryingResonance", "dynamicsInteraction", "ambienceInteraction",
    "arrangementOrMasking", "monitoringOrLevelBias", "hostWorkflow", "unknown",
}
VALID_ACTIONS = {
    "askClarifyingQuestion", "inspectOrConfirmCurrentState", "bypassProcessor",
    "enableProcessor", "openNativeProcessor", "setControl", "sweepControl",
    "compareBypass", "levelMatchComparison", "recordAlternateTake",
    "changeMicrophonePosition", "adjustPerformanceApproach",
    "restorePreviousState", "reportObservation", "stopAndPreserve",
    "reportLimitation",
}
VALID_ACTORS = {"userManual", "trackSmithReadOnlyAnalysis", "trackSmithPreviewDemonstration"}
VALID_FEEDBACK = {"better", "worse", "noChange", "notSure", "notApplicable", "cannotFindControl", "done", "undo"}
VALID_PROVENANCE = {
    "userReported", "locallyMeasured", "appleDocumentedBehavior",
    "directLogicEmpiricalEvidence", "peerReviewedResearch",
    "professionalPracticeHeuristic", "trackSmithProductHeuristic",
    "userConfirmedExperimentOutcome",
}
VALID_UNITS = {
    "boolean", "enumeration", "decibels", "hertz", "milliseconds", "seconds",
    "ratio", "q", "percent", "noteValue", "textObservation",
}
MUTATING_ACTIONS = {"bypassProcessor", "enableProcessor", "setControl", "sweepControl"}
LOCATED_ACTIONS = {"openNativeProcessor", "setControl", "sweepControl", "bypassProcessor"}

COORDINATE_PATTERNS = [
    re.compile(r"\bx\s*=\s*\d+"),
    re.compile(r"\by\s*=\s*\d+"),
    re.compile(r"\b\d{2,4}\s*,\s*\d{2,4}\b"),
    re.compile(r"pixel"),
    re.compile(r"coordinate"),
]
KEY_COMMAND_MARKERS = ["⌘", "⌥", "cmd+", "command+", "option+", "key command", "press command", "shortcut key"]
DESTRUCTIVE_MARKERS = [
    "bounce in place", "normalize the file", "flatten", "replace the file",
    "overwrite", "delete the region", "delete the file", "convert the region",
    "destructive",
]
FALSE_PROOF_MARKERS = [
    "proves you are", "proved you are", "the analyzer proved",
    "measurement proves", "this proves the vocal is", "objectively nasal",
]


def fail(message: str) -> None:
    print(f"TUTOR_PROCEDURE_AUDIT_FAILED: {message}", file=sys.stderr)
    raise SystemExit(1)


def audit_step(step: dict, recognized: set, local_ids: set) -> None:
    sid = step["id"]
    if step["actionKind"] not in VALID_ACTIONS:
        fail(f"{sid}: invalid actionKind")
    if step["actor"] not in VALID_ACTORS:
        fail(f"{sid}: invalid actor")
    if step["actor"] != "userManual" and step["actionKind"] in MUTATING_ACTIONS:
        fail(f"{sid}: only the user may perform mutating Logic actions")
    if not step["stopCondition"].strip():
        fail(f"{sid}: missing stop condition")
    if not step["listenFor"].strip():
        fail(f"{sid}: missing listening cue")
    if not step["undoInstruction"].strip():
        fail(f"{sid}: missing undo")
    if len(step.get("substeps", [])) > 4:
        fail(f"{sid}: more than 4 visible substeps")
    if not step["supportedFeedback"]:
        fail(f"{sid}: no supported feedback")
    for feedback in step["supportedFeedback"]:
        if feedback not in VALID_FEEDBACK:
            fail(f"{sid}: invalid feedback {feedback}")
    if step["actionKind"] in MUTATING_ACTIONS:
        if not step.get("preservationChecks"):
            fail(f"{sid}: mutating step lacks preservation checks")
        if len(step["undoInstruction"].strip()) < 8:
            fail(f"{sid}: mutating step lacks a real rollback")
    location = step.get("location")
    if location is None:
        if step["actionKind"] in LOCATED_ACTIONS:
            fail(f"{sid}: located action without a versioned UI location")
    else:
        if not location.get("logicVersion") or not location.get("navigationLabels"):
            fail(f"{sid}: unversioned UI location")
        if not location.get("sourceReferences"):
            fail(f"{sid}: UI location without source references")
        if location.get("verification") not in {"documentary", "directlyVerified", "documentaryAndDirectlyVerified"}:
            fail(f"{sid}: invalid UI verification status")
        processor = location.get("processorIdentity")
        if processor is not None and processor not in recognized:
            fail(f"{sid}: unrecognized processor identity {processor}")
    for parameter in step.get("parameters", []):
        control = parameter["controlIdentity"]
        if parameter["unit"] not in VALID_UNITS:
            fail(f"{sid}/{control}: invalid unit")
        minimum = parameter.get("minimumValue")
        maximum = parameter.get("maximumValue")
        start = parameter.get("safeStartingValue")
        if minimum is not None and maximum is not None:
            if minimum > maximum:
                fail(f"{sid}/{control}: minimum above maximum")
            if start is not None and not (minimum <= start <= maximum):
                fail(f"{sid}/{control}: starting value out of range")
        if not parameter["rollbackValueDescription"].strip():
            fail(f"{sid}/{control}: missing rollback value")
        if not parameter["stopCondition"].strip():
            fail(f"{sid}/{control}: missing parameter stop condition")
        if parameter["adjustmentMethod"] in {"slowContinuousSweep", "steppedAdjustment"}:
            if parameter.get("maximumRecommendedExcursion") is None:
                fail(f"{sid}/{control}: sweep or stepped adjustment without excursion bound")
    for branch in step.get("branches", []):
        if branch["feedback"] not in VALID_FEEDBACK:
            fail(f"{sid}: branch with invalid feedback")
        target = branch.get("nextStepID")
        if target is not None and target not in local_ids:
            fail(f"{sid}: branch target {target} not in procedure")
    corpus = " ".join(
        [
            step["title"], step["instruction"], step["reason"],
            step["technicalExplanation"], step["listenFor"], step["expectedResult"],
            step["commonSideEffect"], step["stopCondition"], step["undoInstruction"],
        ]
        + step.get("substeps", [])
    ).lower()
    for pattern in COORDINATE_PATTERNS:
        if pattern.search(corpus):
            fail(f"{sid}: coordinate-like content")
    for marker in KEY_COMMAND_MARKERS:
        if marker in corpus:
            fail(f"{sid}: key-command content")
    for marker in DESTRUCTIVE_MARKERS:
        if marker in corpus:
            fail(f"{sid}: destructive instruction content")
    for marker in FALSE_PROOF_MARKERS:
        if marker in corpus:
            fail(f"{sid}: claims a metric proves a subjective diagnosis")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=pathlib.Path, default=DEFAULT_INPUT)
    args = parser.parse_args()

    catalog = json.loads(args.input.read_text(encoding="utf-8"))
    if catalog.get("schemaVersion") != EXPECTED_SCHEMA:
        fail("unexpected schemaVersion")
    recognized = set(catalog.get("recognizedProcessorIdentities", []))
    if not recognized:
        fail("no recognized processor identities")
    procedures = catalog.get("procedures", [])
    if not procedures:
        fail("empty catalog")

    procedure_ids: set = set()
    step_ids: set = set()
    step_count = 0
    for procedure in procedures:
        pid = procedure["id"]
        if pid in procedure_ids:
            fail(f"duplicate procedure ID {pid}")
        procedure_ids.add(pid)
        if procedure.get("grantsExecutionAuthority") is not False:
            fail(f"{pid}: grantsExecutionAuthority must be false")
        if not procedure.get("supportedSourceTypes"):
            fail(f"{pid}: no supported source types")
        for source in procedure["supportedSourceTypes"]:
            if source not in VALID_SOURCE_TYPES:
                fail(f"{pid}: invalid source type {source}")
        for issue in procedure.get("supportedIssues", []):
            if issue not in VALID_ISSUES:
                fail(f"{pid}: invalid issue {issue}")
        for cause in procedure.get("candidateCauses", []):
            if cause not in VALID_CAUSES:
                fail(f"{pid}: invalid cause {cause}")
        if not procedure.get("sourceReferences"):
            fail(f"{pid}: missing provenance")
        for reference in procedure["sourceReferences"]:
            if reference["provenanceClass"] not in VALID_PROVENANCE:
                fail(f"{pid}: invalid provenance class")
        for identity in procedure.get("processorIdentities", []):
            if identity not in recognized:
                fail(f"{pid}: unrecognized processor identity {identity}")
        local_ids = {step["id"] for step in procedure["steps"]}
        if procedure["entryStepID"] not in local_ids:
            fail(f"{pid}: entry step missing")
        for step in procedure["steps"]:
            if step["id"] in step_ids:
                fail(f"duplicate step ID {step['id']}")
            step_ids.add(step["id"])
            if step["procedureID"] != pid:
                fail(f"{step['id']}: procedureID mismatch")
            audit_step(step, recognized, local_ids)
            step_count += 1
        for alternative in procedure.get("nonDSPAlternativeProcedureIDs", []):
            if alternative not in {p["id"] for p in procedures}:
                fail(f"{pid}: unknown non-DSP alternative {alternative}")
        if not procedure.get("subjectiveListeningBoundary", "").strip():
            fail(f"{pid}: missing subjective-listening boundary")

    print(f"TUTOR_PROCEDURE_AUDIT_OK procedures={len(procedures)} steps={step_count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
