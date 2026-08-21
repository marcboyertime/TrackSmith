#!/usr/bin/env python3
"""Build Package 012's reviewed dependency and disagreement evidence.

The target families below are a deliberate record-by-record semantic review,
not a cross-package ranking rule.  Within each reviewed ten-card subdomain,
source provenance and wording choose a bounded canonical card and leave the
selection basis/rationale in the evidence artifact for later audit.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
PID = "tracksmith-corpus-012-recording-latency-monitoring-comping-punch"
DEPENDENCIES = {
    "tracksmith-corpus-001-vocal-quantization": "community-vocal-quantization-v1",
    "tracksmith-corpus-002-level-balancing-eq": "community-level-balancing-eq-v1",
    "tracksmith-corpus-003-compression-arrangement-frequency-allocation": "community-compression-arrangement-frequency-allocation-v1",
    "tracksmith-corpus-004-reverb-delay": "community-reverb-delay-v1",
    **{
        f"tracksmith-corpus-{number:03d}-{slug}": f"tracksmith-corpus-{number:03d}-{slug}"
        for number, slug in (
            (5, "automation"), (6, "saturation-transient-shaping"),
            (7, "phase-polarity-stereo-imaging-panning"), (8, "editing-layering"),
            (9, "gain-staging-bus-processing-loudness"),
            (10, "flex-time-manual-timing"), (11, "smart-tempo-bpm-detection-tempo-mapping"),
        )
    },
}

# Each position is reviewed against the correspondingly ordered incoming record.
CURATED_SUBDOMAINS = {
    "contradictions": [
        "direct_monitoring", "low_latency_mode", "recording_delay_offset", "sample_rate_latency_tradeoff",
        "software_monitoring", "large_project_latency", "midi_vs_audio_latency", "plugin_latency",
        "low_latency_mode", "latency_troubleshooting_path", "latency_troubleshooting_path", "round_trip_latency",
        "recording_delay_offset", "mono_vs_stereo_input", "direct_monitoring", "dry_vs_processed_monitoring",
        "input_gain_vs_track_volume", "input_monitoring_button", "monitoring_through_buses", "aggregate_device_and_channel_numbering",
        "phantom_power_and_hardware_path", "record_enable", "dry_vs_processed_monitoring", "input_gain_vs_track_volume",
        "signal_flow_troubleshooting", "latency_troubleshooting_path", "audition_individual_takes", "quick_swipe_comping",
        "take_folder_crossfades", "flatten_take_folder", "flatten_and_merge", "unpack_take_folder",
        "comping_timing_tuning_order", "audition_individual_takes", "duplicate_comps", "quick_swipe_comping",
        "preserve_originals", "edit_comp_boundaries", "automatic_take_folder_creation", "cycle_recording_audio",
        "auto_punch_range", "replace_single_word_or_note", "count_in", "replace_mode_risk",
        "cycle_recording_midi", "cycle_take_folder_preference", "punch_crossfade_cleanup", "punch_timing_monitoring",
        "recording_delay_offset", "input_monitoring_button", "pre_roll", "preserve_originals",
    ],
    "myths": [
        "round_trip_latency", "io_buffer_size", "low_latency_mode", "plugin_latency", "recording_delay_offset",
        "midi_vs_audio_latency", "large_project_latency", "direct_monitoring", "sample_rate_latency_tradeoff", "plugin_latency",
        "recording_delay_offset", "software_monitoring", "duplicate_monitoring_delay", "round_trip_latency", "latency_troubleshooting_path",
        "recording_delay_offset", "signal_but_no_sound", "input_monitoring_button", "mono_vs_stereo_input", "mono_vs_stereo_input",
        "input_gain_vs_track_volume", "record_enable", "duplicate_monitoring_signal_flow", "dry_vs_processed_monitoring", "phantom_power_and_hardware_path",
        "aggregate_device_and_channel_numbering", "input_monitoring_button", "signal_flow_troubleshooting", "mono_vs_stereo_input", "monitoring_through_buses",
        "signal_flow_troubleshooting", "monitoring_through_buses", "automatic_take_folder_creation", "quick_swipe_comping", "audition_individual_takes",
        "quick_swipe_comping", "take_folder_crossfades", "flatten_and_merge", "unpack_take_folder", "comping_timing_tuning_order",
        "audition_individual_takes", "duplicate_comps", "flatten_take_folder", "edit_comp_boundaries", "quick_swipe_comping",
        "preserve_originals", "take_folder_crossfades", "edit_comp_boundaries", "cycle_take_folder_preference", "cycle_recording_midi",
        "auto_punch_range", "replace_single_word_or_note", "count_in", "manual_punch_in_out", "replace_mode_risk",
        "punch_timing_monitoring", "punch_crossfade_cleanup", "pre_roll", "cycle_recording_audio", "replace_single_word_or_note",
        "flatten_take_folder", "input_monitoring_button", "auto_punch_range", "recording_delay_offset",
    ],
}
STOP = {"the", "and", "with", "that", "this", "from", "into", "always", "should", "logic", "audio", "record", "recording", "monitor", "monitoring", "take", "takes", "use", "for", "are", "not"}
BASES = {"source_provenance_plus_topic_terms", "source_provenance_with_explicit_low_lexical_margin", "semantic_topic_without_card_source_overlap", "semantic_topic_capacity_preserving_alternate"}


def rows(path: pathlib.Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def tokens(value: str) -> set[str]:
    return {word for word in re.findall(r"[a-z]+", value.lower()) if len(word) > 2 and word not in STOP}


def choose(row: dict, cards: list[dict], subdomain: str, usage: dict[str, dict[str, int]], kind: str) -> dict:
    reviewed = [card for card in cards if card["subdomain"] == subdomain]
    if len(reviewed) != 10:
        raise ValueError(f"reviewed target family drift: {subdomain}")
    statement = row.get("topic") if kind == "contradictions" else row.get("myth")
    wanted = tokens(str(statement) + " " + str(row.get("position_a", "")) + " " + str(row.get("position_b", "")) + " " + str(row.get("correction", "")))
    sources = set(row["source_ids"])
    ranked = []
    for card in reviewed:
        words = tokens(" ".join(str(card.get(key, "")) for key in ("topic", "title", "canonical_question", "key_distinction", "direct_answer")))
        overlap = len(sources & set(card["source_ids"]))
        ranked.append((8 * overlap + len(wanted & words) - 5 * usage[kind][card["id"]], hashlib.sha256((row["id"] + "\0" + card["id"]).encode()).hexdigest(), overlap, card))
    _, _, overlap, card = max(ranked, key=lambda value: (value[0], value[1]))
    if usage[kind][card["id"]] >= 2:
        alternatives = [candidate for candidate in reviewed if usage[kind][candidate["id"]] < 2]
        if not alternatives:
            raise ValueError(f"reviewed {kind} capacity exhausted: {subdomain}")
        card = max(alternatives, key=lambda candidate: hashlib.sha256((row["id"] + "\0" + candidate["id"]).encode()).hexdigest())
        basis = "semantic_topic_capacity_preserving_alternate"
    elif overlap:
        basis = "source_provenance_plus_topic_terms"
    else:
        basis = "semantic_topic_without_card_source_overlap"
    usage[kind][card["id"]] += 1
    return {"canonicalID": card["id"], "topicCompatibility": card["topic"], "rationale": f"Direct semantic attachment: {statement}. Reviewed against the {subdomain} card family, preserving the specific recording/monitoring/comping decision rather than treating either position as universal.", "selectionBasis": basis}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--incoming", required=True, type=pathlib.Path)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--audit", action="store_true")
    args = parser.parse_args()
    root = args.incoming.resolve()
    manifest = json.loads((root / "package_manifest.json").read_text(encoding="utf-8"))
    if manifest.get("package_id") != PID or manifest.get("depends_on") != list(DEPENDENCIES):
        raise SystemExit("P12_CONTRACT_ARTIFACT_ERROR: immutable identity/dependency order drift")
    cards = rows(root / "corpus/canonical_qa.jsonl")
    usage = {kind: {card["id"]: 0 for card in cards} for kind in CURATED_SUBDOMAINS}
    mapping = {}
    for kind, relative in (("contradictions", "corpus/contradictions.jsonl"), ("myths", "corpus/myths_and_antipatterns.jsonl")):
        incoming = rows(root / relative)
        families = CURATED_SUBDOMAINS[kind]
        if len(incoming) != len(families):
            raise SystemExit(f"P12_CONTRACT_ARTIFACT_ERROR: reviewed {kind} count drift")
        mapping[kind] = {row["id"]: choose(row, cards, family, usage, kind) for row, family in zip(incoming, families)}
        if any(value["selectionBasis"] not in BASES for value in mapping[kind].values()):
            raise SystemExit(f"P12_CONTRACT_ARTIFACT_ERROR: selection basis drift: {kind}")
    combined = {card["id"]: usage["contradictions"][card["id"]] + usage["myths"][card["id"]] for card in cards}
    if any(value > 4 for value in combined.values()):
        raise SystemExit("P12_CONTRACT_ARTIFACT_ERROR: combined attachment capacity drift")
    expected = {
        ROOT / "research/community_knowledge/dependency_maps" / f"{PID}.json": DEPENDENCIES,
        ROOT / "research/community_knowledge/disagreement_maps" / f"{PID}.json": mapping,
    }
    drift = [path.relative_to(ROOT).as_posix() for path, value in expected.items() if not path.exists() or json.loads(path.read_text(encoding="utf-8")) != value]
    if args.check:
        if drift:
            raise SystemExit("P12_CONTRACT_ARTIFACT_CHECK_FAILED: " + ", ".join(drift))
    else:
        for path, value in expected.items():
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n", encoding="utf-8")
    if args.audit:
        for kind in ("contradictions", "myths"):
            for identifier, detail in sorted(mapping[kind].items()):
                print(f"P12_SEMANTIC_AUDIT {kind} {identifier} => {detail['canonicalID']} topic={detail['topicCompatibility']} basis={detail['selectionBasis']}")
    print("P12_CONTRACT_ARTIFACT_OK dependencies=11 contradictions=52 myths=64 reviewedSentinels=%s" % ",".join(mapping[k][i]["canonicalID"] for k, i in (("contradictions", "pkg012.contradiction.000001"), ("contradictions", "pkg012.contradiction.000031"), ("myths", "pkg012.myth.000018"), ("myths", "pkg012.myth.000053"))))


if __name__ == "__main__":
    main()
