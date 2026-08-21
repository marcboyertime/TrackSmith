#!/usr/bin/env python3
"""Build Package 014's repository-owned disagreement review artifacts.

The incoming package supplies evidence rows, not import authority.  Each row is
attached only to its reviewed semantic family before a source-aware choice among
that family's ten canonical variants is made.  This deliberately rules out a
global lexical "best match" that could cross an automation/MIDI/routing boundary.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
PID = "tracksmith-corpus-014-sidechain-automation-midi-groove-velocity-transform"
DEPENDENCIES = {
    "tracksmith-corpus-001-vocal-quantization": "community-vocal-quantization-v1",
    "tracksmith-corpus-002-level-balancing-eq": "community-level-balancing-eq-v1",
    "tracksmith-corpus-003-compression-arrangement-frequency-allocation": "community-compression-arrangement-frequency-allocation-v1",
    "tracksmith-corpus-004-reverb-delay": "community-reverb-delay-v1",
    **{f"tracksmith-corpus-{number:03d}-{slug}": f"tracksmith-corpus-{number:03d}-{slug}" for number, slug in (
        (5, "automation"), (6, "saturation-transient-shaping"), (7, "phase-polarity-stereo-imaging-panning"),
        (8, "editing-layering"), (9, "gain-staging-bus-processing-loudness"),
        (10, "flex-time-manual-timing"), (11, "smart-tempo-bpm-detection-tempo-mapping"),
        (12, "recording-latency-monitoring-comping-punch"),
        (13, "sends-buses-auxes-track-stacks-groups-submixes"),
    )},
}

# The first 66 myths mirror the 66 declared incoming contradiction families.  The
# final twelve are individually reviewed sentinels, not lexical fallbacks.
MYTH_EXTRA_FAMILIES = [
    "sidechain_concept", "rhythmic_pumping", "sidechain_not_reacting", "write_mode",
    "fader_snapback", "track_vs_region_automation", "q_strength", "random_timing_small",
    "matching_velocity_between_notes", "velocity_vs_expression_volume", "velocity_accents",
    "transform_undo_and_scope",
]
STOP = {"the", "and", "with", "that", "this", "from", "into", "always", "should", "logic", "audio", "track", "tracks", "one", "use", "for", "are", "not"}


def rows(path: pathlib.Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def tokens(value: str) -> set[str]:
    return {word for word in re.findall(r"[a-z]+", value.lower()) if len(word) > 2 and word not in STOP}


def choose(row: dict, cards: list[dict], topic: str, usage: dict[str, dict[str, int]], kind: str) -> dict:
    statement = row["topic"] if kind == "contradictions" else row["myth"]
    candidates = [card for card in cards if card["topic"] == topic]
    if len(candidates) != 10:
        raise ValueError(f"reviewed topic family drift: {topic}")
    wanted = tokens(" ".join(str(row.get(key, "")) for key in ("topic", "myth", "position_a", "position_b", "correction", "safer_principle")))
    sources = set(row["source_ids"])
    ranked = []
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
    return {
        "canonicalID": card["id"],
        "topicCompatibility": topic,
        "rationale": f"Direct semantic attachment: {statement}. Reviewed only within the {topic} family, preserving this row's statement and registered source provenance rather than promoting either position as a universal rule.",
        "selectionBasis": "source_provenance_plus_topic_terms" if overlap else "semantic_topic_without_card_source_overlap",
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--incoming", required=True, type=pathlib.Path)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    root = args.incoming.resolve()
    manifest = json.loads((root / "package_manifest.json").read_text(encoding="utf-8"))
    if manifest.get("package_id") != PID or manifest.get("depends_on") != list(DEPENDENCIES):
        raise SystemExit("P14_CONTRACT_ARTIFACT_ERROR: immutable identity/dependency order drift")
    cards = rows(root / "corpus/canonical_qa.jsonl")
    if len(cards) != 660 or any(len([card for card in cards if card["topic"] == topic]) != 10 for topic in {card["topic"] for card in cards}):
        raise SystemExit("P14_CONTRACT_ARTIFACT_ERROR: 66x10 canonical distinction matrix drift")
    contradictions = rows(root / "corpus/contradictions.jsonl")
    myths = rows(root / "corpus/myths_and_antipatterns.jsonl")
    contradiction_topics = [row.get("topic") for row in contradictions]
    myth_topics = contradiction_topics + MYTH_EXTRA_FAMILIES
    if len(contradictions) != 66 or len(myths) != 78 or len(myth_topics) != len(myths) or any(not topic for topic in contradiction_topics):
        raise SystemExit("P14_CONTRACT_ARTIFACT_ERROR: reviewed disagreement topic count drift")
    usage = {kind: {card["id"]: 0 for card in cards} for kind in ("contradictions", "myths")}
    mapping = {
        "contradictions": {row["id"]: choose(row, cards, topic, usage, "contradictions") for row, topic in zip(contradictions, contradiction_topics)},
        "myths": {row["id"]: choose(row, cards, topic, usage, "myths") for row, topic in zip(myths, myth_topics)},
    }
    combined = {card["id"]: usage["contradictions"][card["id"]] + usage["myths"][card["id"]] for card in cards}
    if any(value > 2 for values in usage.values() for value in values.values()) or any(value > 4 for value in combined.values()):
        raise SystemExit("P14_CONTRACT_ARTIFACT_ERROR: disagreement capacity drift")
    expected = {
        ROOT / "research/community_knowledge/dependency_maps" / f"{PID}.json": DEPENDENCIES,
        ROOT / "research/community_knowledge/disagreement_maps" / f"{PID}.json": mapping,
    }
    drift = [path.relative_to(ROOT).as_posix() for path, value in expected.items() if not path.exists() or json.loads(path.read_text(encoding="utf-8")) != value]
    if args.check:
        if drift:
            raise SystemExit("P14_CONTRACT_ARTIFACT_CHECK_FAILED: " + ", ".join(drift))
    else:
        for path, value in expected.items():
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n", encoding="utf-8")
    dep_path = ROOT / "research/community_knowledge/dependency_maps" / f"{PID}.json"
    map_path = ROOT / "research/community_knowledge/disagreement_maps" / f"{PID}.json"
    print("P14_CONTRACT_ARTIFACT_OK dependencies=13 contradictions=66 myths=78 dependencySHA256=%s disagreementSHA256=%s" % (hashlib.sha256(dep_path.read_bytes()).hexdigest(), hashlib.sha256(map_path.read_bytes()).hexdigest()))


if __name__ == "__main__":
    main()
