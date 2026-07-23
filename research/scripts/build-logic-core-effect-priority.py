#!/usr/bin/env python3
"""Build TrackSmith's source-grounded Logic core-effect review priority.

This is a product/research priority, not a claim about global plug-in telemetry.
It combines recurrence in TrackSmith's curated professional cases with the
processing roles needed by its six source classes and semantic request corpus.
"""

from __future__ import annotations

import hashlib
import json
import pathlib
import re
from collections import Counter
from typing import Any


ROOT = pathlib.Path(__file__).resolve().parents[2]
KNOWLEDGE = ROOT / "research/knowledge"
OUTPUT = KNOWLEDGE / "logic-pro-12.3-core-effect-priority.json"
SWIFT_OUTPUT = (
    ROOT
    / "packages/ProductionIntelligence/Sources/ProductionIntelligence/LogicCoreEffectPriority.generated.swift"
)
EFFECTS_PATH = KNOWLEDGE / "logic-pro-12.3-effects-knowledge.json"
CASE_PATHS = (
    KNOWLEDGE / "PRODUCER_JUDGMENT_CORPUS.jsonl",
    KNOWLEDGE / "PRODUCER_JUDGMENT_CORPUS_PART_B.jsonl",
)

CASE_FIELDS = (
    "artistic_goal",
    "problem",
    "listening_diagnosis",
    "contextual_interpretation",
    "intervention",
    "processing_order",
    "rejected_interventions",
    "audible_result",
    "preservation_tradeoff",
    "stopping_criterion",
    "tracksmith_implication",
)

RECURRENCE_PATTERNS = {
    "gain_balance_automation": r"\b(?:gain|fader|balance|automation|ride|level)\w*\b",
    "compression_dynamics": r"\b(?:compress|limiter|limit|dynamic|gain reduction|parallel compression)\w*\b",
    "eq_filter_tone": r"\b(?:eq|equaliz|filter|high[- ]?pass|low[- ]?pass|tone|spectr)\w*\b",
    "transient_envelope": r"\b(?:transient|attack|release|sustain|envelope|punch)\w*\b",
    "ambience_reverb_delay": r"\b(?:reverb|delay|echo|ambience|room|space|predelay)\w*\b",
    "pitch_timing_edit": r"\b(?:pitch|tun|timing|align|edit|comping|flex)\w*\b",
    "cleanup_gate_deess": r"\b(?:de[- ]?ess|sibil|gate|noise|cleanup|clean up|hum|click)\w*\b",
    "saturation_distortion": r"\b(?:saturat|distort|drive|clip|tape|harmonic)\w*\b",
    "stereo_pan_phase": r"\b(?:stereo|pan|phase|polarity|mono|width|mid.side|m/s)\w*\b",
}

# Processing order means "review/characterize first," not "always insert in
# this order" and not "always use." Gain/balance and meters are included because
# every effect comparison depends on them even though they are not creative FX.
PRIORITY_QUEUE = (
    (1, "Gain", "foundation_gain_and_level_matched_comparison"),
    (2, "Channel EQ", "primary_static_equalization"),
    (3, "Compressor", "primary_dynamics_and_envelope_control"),
    (4, "DeEsser 2", "source_specific_dynamic_high_band_control"),
    (5, "Noise Gate", "source_cleanup_and_envelope_boundary"),
    (6, "ChromaVerb", "algorithmic_reverb_and_depth"),
    (7, "Space Designer", "convolution_reverb_and_space"),
    (8, "Stereo Delay", "general_stereo_delay"),
    (9, "Tape Delay", "colored_feedback_delay"),
    (10, "ChromaGlow", "general_saturation_and_harmonic_color"),
    (11, "Overdrive", "bounded_drive_and_harmonic_color"),
    (12, "Limiter", "peak_control_and_delivery_boundary"),
    (13, "Adaptive Limiter", "lookahead_peak_and_loudness_boundary"),
    (14, "Loudness Meter", "standards_related_host_readout"),
    (15, "MultiMeter", "combined_spectrum_level_and_correlation_observation"),
    (16, "Direction Mixer", "width_mid_side_and_mono_translation"),
    (17, "Correlation Meter", "stereo_phase_risk_observation"),
    (18, "Pitch Correction", "source_specific_pitch_assistance"),
    (19, "Enveloper", "explicit_attack_and_sustain_shaping"),
    (20, "Linear Phase EQ", "latency_phase_and_mastering_equalization_alternative"),
)

LANES = (
    {
        "order": 1,
        "identifier": "foundation_gain_balance_routing_and_metering",
        "logicTools": ["Gain", "Level Meter", "Loudness Meter", "MultiMeter", "Correlation Meter", "Direction Mixer"],
        "whyFirst": "Every processor audition depends on gain, level matching, channel identity, polarity, peak/loudness observation, and mono/stereo translation.",
        "notEstablished": "That a meter can determine artistic quality or that one loudness/width target fits every source.",
    },
    {
        "order": 2,
        "identifier": "equalization_and_filtering",
        "logicTools": ["Channel EQ", "Linear Phase EQ", "Single Band EQ"],
        "whyFirst": "Tone, resonance, masking, bandwidth, headroom, and pre/post nonlinear drive are recurring production decisions across every source class.",
        "notEstablished": "That a spectral peak is a defect or that an adjective maps to one frequency curve.",
    },
    {
        "order": 3,
        "identifier": "compression_and_source_dynamics",
        "logicTools": ["Compressor", "DeEsser 2", "Noise Gate", "Enveloper", "Expander", "Multipressor"],
        "whyFirst": "Level contour, transient/sustain balance, consonant events, cleanup, density, groove, and dynamic preservation recur throughout source and bus work.",
        "notEstablished": "That compression is automatically polish, punch, warmth, or control; detector, timing, level, and source context determine the result.",
    },
    {
        "order": 4,
        "identifier": "reverb_depth_and_ambience",
        "logicTools": ["ChromaVerb", "Space Designer", "Quantec Room Simulator", "EnVerb", "SilverVerb"],
        "whyFirst": "Distance, intimacy, room identity, blend, early/late energy, decay spectrum, and stereo depth are common musician requests that EQ alone cannot satisfy.",
        "notEstablished": "That one decay or predelay value means intimate, distant, expensive, or professional.",
    },
    {
        "order": 5,
        "identifier": "delay_rhythm_and_depth",
        "logicTools": ["Stereo Delay", "Tape Delay", "Delay Designer", "Echo", "Sample Delay"],
        "whyFirst": "Delay can create rhythm, depth, width, sustain, transitions, and masking; feedback and synchronization make it materially stateful.",
        "notEstablished": "That delay is always ambience or that repeats remain safe under feedback, filtering, saturation, and automation.",
    },
    {
        "order": 6,
        "identifier": "saturation_drive_and_harmonic_color",
        "logicTools": ["ChromaGlow", "Overdrive", "Clip Distortion", "Distortion", "Distortion II"],
        "whyFirst": "Musicians frequently ask for density, aggression, warmth, edge, vintage color, or energy without merely raising level; nonlinear options have different spectral and dynamic risks.",
        "notEstablished": "That saturation is inherently warm, analog, flattering, or alias-free, or that louder is better.",
    },
    {
        "order": 7,
        "identifier": "limiting_delivery_and_mastering_observation",
        "logicTools": ["Limiter", "Adaptive Limiter", "Loudness Meter", "MultiMeter", "Mastering Assistant"],
        "whyFirst": "Peak safety, loudness, dynamic preservation, delivery, and gain-biased comparison matter to previews and complete mixes.",
        "notEstablished": "That one LUFS or true-peak value is universally correct or that Logic's mastering suggestions are normative standards.",
    },
    {
        "order": 8,
        "identifier": "stereo_phase_and_mono_translation",
        "logicTools": ["Direction Mixer", "Correlation Meter", "Stereo Spread", "Sample Delay"],
        "whyFirst": "Width requests can damage localization, low-end focus, or mono translation; source and frequency dependence must stay visible.",
        "notEstablished": "That correlation or one width number proves a desirable image.",
    },
    {
        "order": 9,
        "identifier": "pitch_and_source_specific_correction",
        "logicTools": ["Pitch Correction", "Pitch Shifter", "Vocal Transformer"],
        "whyFirst": "Pitch assistance is common for vocals and selected instruments but depends on key, scale, confidence, polyphony, formants, performance intent, and artifacts.",
        "notEstablished": "That correction is required, invisible, or artistically preferable, or that a confidence metric grants permission to tune.",
    },
    {
        "order": 10,
        "identifier": "creative_color_specialized_and_pedalboard",
        "logicTools": ["Bitcrusher", "Pedalboard", "Step FX", "Phat FX", "Remix FX"],
        "whyFirst": "These are valuable creative options after the core production language and safety checks are reliable.",
        "notEstablished": "That lower product priority means lesser artistic value; this is sequencing for broad request coverage, not a quality ranking.",
    },
)


def digest(path: pathlib.Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def load_cases() -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for path in CASE_PATHS:
        rows.extend(json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip())
    identifiers = [row["record_id"] for row in rows]
    if len(identifiers) != len(set(identifiers)):
        raise SystemExit("professional-case corpus contains duplicate record IDs")
    return rows


def recurrence(rows: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    counts: Counter[str] = Counter()
    examples: dict[str, list[str]] = {key: [] for key in RECURRENCE_PATTERNS}
    for row in rows:
        text = " ".join(
            json.dumps(row.get(field, ""), ensure_ascii=False) for field in CASE_FIELDS
        ).lower()
        for category, pattern in RECURRENCE_PATTERNS.items():
            if re.search(pattern, text):
                counts[category] += 1
                if len(examples[category]) < 6:
                    examples[category].append(row["record_id"])
    return {
        category: {
            "casePresenceCount": counts[category],
            "totalCuratedCases": len(rows),
            "exampleRecordIDs": examples[category],
            "interpretationBoundary": "keyword presence in a curated case, not plug-in use frequency or an industry prevalence estimate",
        }
        for category in RECURRENCE_PATTERNS
    }


def swift_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def write_swift_priority(queue: list[dict[str, Any]]) -> None:
    lines = [
        "// Generated by research/scripts/build-logic-core-effect-priority.py.",
        "// Do not edit by hand; update the source-grounded priority generator.",
        "",
        "public enum LogicCoreEffectPriority {",
        "    public static let rankByName: [String: Int] = [",
    ]
    for item in queue:
        lines.append(f"        {swift_string(item['name'])}: {item['order']},")
    lines.extend(
        [
            "    ]",
            "",
            "    public static let evidenceBoundary =",
            "        \"CURATED_58_CASE_ROLE_RECURRENCE_NOT_GLOBAL_USAGE_TELEMETRY_OR_FIXED_PROCESSING_ORDER\"",
            "}",
            "",
        ]
    )
    SWIFT_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    SWIFT_OUTPUT.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    effects = json.loads(EFFECTS_PATH.read_text(encoding="utf-8"))
    by_name = {entry["name"]: entry for entry in effects["entries"]}
    referenced = {
        name for lane in LANES for name in lane["logicTools"]
    } | {name for _, name, _ in PRIORITY_QUEUE}
    missing = sorted(referenced - set(by_name))
    if missing:
        raise SystemExit(f"priority references missing reviewed Logic identities: {missing}")
    if any(by_name[name]["family"].startswith("pedalboard_") for _, name, _ in PRIORITY_QUEUE):
        raise SystemExit("a Pedalboard subeffect entered the first core queue")

    rows = load_cases()
    queue = []
    for order, name, role in PRIORITY_QUEUE:
        entry = by_name[name]
        queue.append(
            {
                "order": order,
                "name": name,
                "identifier": entry["identifier"],
                "family": entry["family"],
                "documentaryPages": entry["manualPages"],
                "reviewStatus": entry["reviewStatus"],
                "empiricalStatus": entry["empiricalStatus"],
                "role": role,
            }
        )

    payload = {
        "schemaVersion": "1.0",
        "product": "TrackSmith",
        "logicVersionContext": "Logic Pro 12.3",
        "generatedDate": "2026-07-18",
        "priorityType": "tracksmith_core_production_coverage_not_global_usage_telemetry",
        "boundaries": {
            "globalPluginUsageFrequencyClaimed": False,
            "artisticImportanceRankingClaimed": False,
            "fixedProcessingOrderClaimed": False,
            "automaticInsertionAuthorityClaimed": False,
            "listeningStillDecisive": True,
            "explanation": "The queue prioritizes broad recurring production roles and TrackSmith request coverage. A lower tier may be the best artistic choice for a particular song.",
        },
        "professionalCaseEvidence": {
            "caseCount": len(rows),
            "sources": [
                {"path": str(path.relative_to(ROOT)), "sha256": digest(path)} for path in CASE_PATHS
            ],
            "recurrenceSignals": recurrence(rows),
        },
        "lanes": LANES,
        "firstEmpiricalAndPracticeQueue": queue,
        "nextDirectHostProcessingQueue": [
            "Channel EQ",
            "Compressor",
            "DeEsser 2",
            "Noise Gate",
            "ChromaVerb",
            "Space Designer",
            "Stereo Delay",
            "Tape Delay",
            "ChromaGlow",
            "Limiter",
            "Direction Mixer",
            "Pitch Correction"
        ],
        "creativeLaneBoundary": {
            "examples": ["Bitcrusher", "Pedalboard", "Step FX", "Phat FX", "Remix FX"],
            "priority": "after_core_processing_roles",
            "reason": "Retained as important creative vocabulary, but not allowed to displace the processors needed for the widest set of everyday production requests.",
        },
    }
    OUTPUT.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    write_swift_priority(queue)
    print(
        f"wrote {OUTPUT} and {SWIFT_OUTPUT}: "
        f"{len(rows)} professional cases, {len(queue)} first-queue identities"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
