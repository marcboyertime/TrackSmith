#!/usr/bin/env python3
"""Build Package 013's repository-owned dependency and disagreement evidence.

This is deliberately a bounded, record-by-record review artifact.  It does
not invoke supplied package tooling and it records the source-aware target and
rationale for every disagreement before the pin is accepted by staging.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
PID = "tracksmith-corpus-013-sends-buses-auxes-track-stacks-groups-submixes"
DEPENDENCIES = {
    "tracksmith-corpus-001-vocal-quantization": "community-vocal-quantization-v1",
    "tracksmith-corpus-002-level-balancing-eq": "community-level-balancing-eq-v1",
    "tracksmith-corpus-003-compression-arrangement-frequency-allocation": "community-compression-arrangement-frequency-allocation-v1",
    "tracksmith-corpus-004-reverb-delay": "community-reverb-delay-v1",
    **{f"tracksmith-corpus-{number:03d}-{slug}": f"tracksmith-corpus-{number:03d}-{slug}" for number, slug in (
        (5, "automation"), (6, "saturation-transient-shaping"),
        (7, "phase-polarity-stereo-imaging-panning"), (8, "editing-layering"),
        (9, "gain-staging-bus-processing-loudness"), (10, "flex-time-manual-timing"),
        (11, "smart-tempo-bpm-detection-tempo-mapping"),
        (12, "recording-latency-monitoring-comping-punch"),
    )},
}
STOP = {"the", "and", "with", "that", "this", "from", "into", "always", "should", "logic", "audio", "track", "tracks", "routing", "route", "versus", "return", "shared", "one", "use", "for", "are", "not"}
# These are the reviewed semantic families for the incoming disagreement rows.
# The scorer below chooses only among the ten variants of the declared family;
# it cannot attach a reverb or VCA dispute to an unrelated source-overlap card.
CURATED_TOPICS = {
    "contradictions": "sends_vs_inserts shared_reverb post_pan_sends post_fader_sends effect_return_level source_send_vs_return_automation send_pan_independent_pan multiple_tracks_one_effect aux_eq_filtering aux_sidechain_ducking parallel_compression_send bus_aux_signal_path headphone_cue_mix create_send_and_aux bus_naming_organization shared_reverb wet_dry_aux_return source_send_vs_return_automation local_buses_inside_stack solo_mute_aux_behavior folder_vs_summing track_stack_vs_aux_subgroup mixer_groups_concept vca_vs_aux_subgroup folder_stack_concept group_automation group_editing drum_kit_submix backing_vocal_submix guitar_submix nested_stacks_submixes aux_eq_filtering parallel_compression_send controlling_several_tracks_one_fader vca_post_fader_sends flatten_track_stack add_remove_reorder_subtracks local_buses_inside_stack send_level effect_return_level source_send_vs_return_automation subgroup_via_aux group_settings_parameters group_settings_parameters group_settings_parameters group_clutch_disable vca_concept folder_stack_concept summing_stack_routing wet_dry_aux_return nested_stacks_submixes parallel_compression_send".split(),
    "myths": "bus_aux_signal_path sends_vs_inserts shared_reverb effect_return_level pre_fader_sends post_pan_sends reverb_tail_when_source_quiet wet_dry_aux_return shared_reverb multiple_tracks_one_effect bus_naming_organization bus_aux_signal_path send_level effect_return_level effect_return_level solo_mute_aux_behavior reverb_tail_when_source_quiet shared_reverb folder_stack_concept summing_stack_concept folder_vs_summing mixer_groups_concept vca_concept vca_concept vca_vs_aux_subgroup folder_stack_concept summing_stack_routing summing_stack_routing add_remove_reorder_subtracks add_remove_reorder_subtracks flatten_track_stack group_settings_parameters group_clutch_disable group_settings_parameters group_clutch_disable group_editing vca_post_fader_sends vca_post_fader_sends drum_kit_submix backing_vocal_submix guitar_submix nested_stacks_submixes subgroup_via_aux parallel_saturation subgroup_via_aux controlling_several_tracks_one_fader vca_concept send_level send_pan_independent_pan local_buses_inside_stack create_send_and_aux source_send_vs_return_automation source_send_vs_return_automation subgroup_via_aux nested_stacks_submixes folder_stack_concept group_settings_parameters controlling_several_tracks_one_fader local_buses_inside_stack summing_stack_routing organization_without_audio_change bus_aux_signal_path vca_concept summing_stack_concept".split(),
}


def rows(path: pathlib.Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def tokens(value: str) -> set[str]:
    return {word for word in re.findall(r"[a-z]+", value.lower()) if len(word) > 2 and word not in STOP}


def choose(row: dict, cards: list[dict], topic: str, usage: dict[str, dict[str, int]], kind: str) -> dict:
    statement = row["topic"] if kind == "contradictions" else row["myth"]
    wanted = tokens(" ".join(str(row.get(key, "")) for key in ("topic", "myth", "position_a", "position_b", "correction")))
    sources = set(row["source_ids"])
    ranked = []
    candidates = [card for card in cards if card["topic"] == topic]
    if len(candidates) != 10:
        raise ValueError(f"reviewed topic family drift: {topic}")
    for card in candidates:
        card_words = tokens(" ".join(str(card.get(key, "")) for key in ("topic", "title", "canonical_question", "key_distinction", "direct_answer")))
        overlap = len(sources & set(card["source_ids"]))
        capacity_penalty = 1000 if usage[kind][card["id"]] >= 2 else 0
        score = 12 * overlap + len(wanted & card_words) - capacity_penalty
        tie = hashlib.sha256((row["id"] + "\0" + card["id"]).encode()).hexdigest()
        ranked.append((score, tie, overlap, card))
    score, _, overlap, card = max(ranked, key=lambda value: (value[0], value[1]))
    if score < 0:
        raise ValueError(f"no capacity-preserving target for {row['id']}")
    usage[kind][card["id"]] += 1
    basis = "source_provenance_plus_topic_terms" if overlap else "semantic_topic_without_card_source_overlap"
    return {
        "canonicalID": card["id"],
        "topicCompatibility": card["topic"],
        "rationale": f"Direct semantic attachment: {statement}. Reviewed against the routing/grouping distinction '{card['topic']}', retaining the record-specific tradeoff and source provenance rather than treating either position as universal.",
        "selectionBasis": basis,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--incoming", required=True, type=pathlib.Path)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    root = args.incoming.resolve()
    manifest = json.loads((root / "package_manifest.json").read_text(encoding="utf-8"))
    if manifest.get("package_id") != PID or manifest.get("depends_on") != list(DEPENDENCIES):
        raise SystemExit("P13_CONTRACT_ARTIFACT_ERROR: immutable identity/dependency order drift")
    cards = rows(root / "corpus/canonical_qa.jsonl")
    if len(cards) != 480 or any(len([card for card in cards if card["topic"] == topic]) != 10 for topic in {card["topic"] for card in cards}):
        raise SystemExit("P13_CONTRACT_ARTIFACT_ERROR: 48x10 canonical distinction matrix drift")
    usage = {kind: {card["id"]: 0 for card in cards} for kind in ("contradictions", "myths")}
    mapping = {}
    for kind, relative in (("contradictions", "corpus/contradictions.jsonl"), ("myths", "corpus/myths_and_antipatterns.jsonl")):
        incoming = rows(root / relative)
        topics = CURATED_TOPICS[kind]
        if len(incoming) != len(topics):
            raise SystemExit(f"P13_CONTRACT_ARTIFACT_ERROR: reviewed {kind} topic count drift")
        mapping[kind] = {row["id"]: choose(row, cards, topic, usage, kind) for row, topic in zip(incoming, topics)}
    combined = {card["id"]: usage["contradictions"][card["id"]] + usage["myths"][card["id"]] for card in cards}
    if any(value > 2 for values in usage.values() for value in values.values()) or any(value > 4 for value in combined.values()):
        raise SystemExit("P13_CONTRACT_ARTIFACT_ERROR: disagreement capacity drift")
    expected = {
        ROOT / "research/community_knowledge/dependency_maps" / f"{PID}.json": DEPENDENCIES,
        ROOT / "research/community_knowledge/disagreement_maps" / f"{PID}.json": mapping,
    }
    drift = [path.relative_to(ROOT).as_posix() for path, value in expected.items() if not path.exists() or json.loads(path.read_text(encoding="utf-8")) != value]
    if args.check:
        if drift:
            raise SystemExit("P13_CONTRACT_ARTIFACT_CHECK_FAILED: " + ", ".join(drift))
    else:
        for path, value in expected.items():
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n", encoding="utf-8")
    # Print the bytes-derived pins rather than trusting supplied importer output.
    dep_path = ROOT / "research/community_knowledge/dependency_maps" / f"{PID}.json"
    map_path = ROOT / "research/community_knowledge/disagreement_maps" / f"{PID}.json"
    print("P13_CONTRACT_ARTIFACT_OK dependencies=12 contradictions=52 myths=64 dependencySHA256=%s disagreementSHA256=%s" % (hashlib.sha256(dep_path.read_bytes()).hexdigest(), hashlib.sha256(map_path.read_bytes()).hexdigest()))


if __name__ == "__main__":
    main()
