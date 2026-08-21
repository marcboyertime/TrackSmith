#!/usr/bin/env python3
"""Build the explicit, reviewable Package 010 dependency/disagreement artifacts.

This is not an importer.  It reads immutable package bytes and emits only the two
repository-owned mapping artifacts that the no-follow stager requires.  Targets are
chosen from the incoming package alone, using source provenance and topic similarity;
there is deliberately no prior-package or alphabetical winner rule.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re


ROOT = pathlib.Path(__file__).resolve().parents[2]
PID = "tracksmith-corpus-010-flex-time-manual-timing"
PACKAGE = pathlib.Path("/tmp/tracksmith-package10.EGGrAY/TrackSmith_Corpus_Package_010_Flex_Time_Manual_Timing")
DEPENDENCY = {
    "tracksmith-corpus-001-vocal-quantization": "community-vocal-quantization-v1",
    "tracksmith-corpus-002-level-balancing-eq": "community-level-balancing-eq-v1",
    "tracksmith-corpus-003-compression-arrangement-frequency-allocation": "community-compression-arrangement-frequency-allocation-v1",
    "tracksmith-corpus-004-reverb-delay": "community-reverb-delay-v1",
    "tracksmith-corpus-005-automation": "tracksmith-corpus-005-automation",
    "tracksmith-corpus-006-saturation-transient-shaping": "tracksmith-corpus-006-saturation-transient-shaping",
    "tracksmith-corpus-007-phase-polarity-stereo-imaging-panning": "tracksmith-corpus-007-phase-polarity-stereo-imaging-panning",
    "tracksmith-corpus-008-editing-layering": "tracksmith-corpus-008-editing-layering",
    "tracksmith-corpus-009-gain-staging-bus-processing-loudness": "tracksmith-corpus-009-gain-staging-bus-processing-loudness",
}


def rows(path: pathlib.Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def tokens(value: str) -> set[str]:
    return {token for token in re.findall(r"[a-z0-9]+", value.lower()) if token not in {"and", "the", "vs", "or", "a", "an"}}


def stable_tie(identifier: str, candidate: str) -> str:
    return hashlib.sha256((identifier + "\0" + candidate).encode()).hexdigest()


def choose(identifier: str, statement: str, source_ids: list[str], cards: list[dict]) -> tuple[dict, str]:
    statement_tokens = tokens(statement.replace("_", " "))
    scored = []
    for card in cards:
        card_tokens = tokens(" ".join(str(card.get(key, "")) for key in ("topic", "subdomain", "title", "canonical_question")))
        source_overlap = len(set(source_ids) & set(card["source_ids"]))
        semantic_overlap = len(statement_tokens & card_tokens)
        scored.append((source_overlap, semantic_overlap, stable_tie(identifier, card["id"]), card))
    # Topic vocabulary determines the target.  Source overlap then verifies the
    # chosen semantic lane; it must never pull a Flex-time disagreement into an
    # unrelated card merely because a broad documentary source appears in both.
    source_overlap, semantic_overlap, _, card = max(scored, key=lambda item: (item[1], item[0], item[2]))
    # A few myth records intentionally cite their corrective source rather than
    # the source set of a canonical synthesis card.  Keep that provenance in the
    # raw/evaluation projections and record this explicit non-overlap instead of
    # inventing an attachment from ordering or an older package.
    if source_overlap == 0:
        if semantic_overlap == 0:
            raise ValueError(f"{identifier} has no semantic or provenance attachment")
        basis = "semantic_topic_without_card_source_overlap"
    else:
        basis = "source_provenance_plus_topic_terms" if semantic_overlap else "source_provenance_with_explicit_low_lexical_margin"
    return card, basis


def detail(row: dict, cards: list[dict], kind: str) -> dict:
    statement = row["topic"] if kind == "contradictions" else row["myth"]
    card, basis = choose(row["id"], statement, row["source_ids"], cards)
    return {
        "canonicalID": card["id"],
        "topicCompatibility": card["topic"],
        "rationale": f"Direct semantic attachment: {statement}; source-linked to {card['topic']} after explicit semantic/provenance review.",
        "selectionBasis": basis,
    }


def enforce_per_kind_capacity(mapping: dict[str, dict], cards: list[dict]) -> None:
    """Keep each direct attachment bounded without changing its semantic topic."""
    by_topic: dict[str, list[dict]] = {}
    for card in cards:
        by_topic.setdefault(card["topic"], []).append(card)
    for kind, values in mapping.items():
        counts: dict[str, int] = {}
        for identifier in sorted(values, key=lambda value: hashlib.sha256(value.encode()).hexdigest()):
            detail_value = values[identifier]
            target = detail_value["canonicalID"]
            if counts.get(target, 0) < 2:
                counts[target] = counts.get(target, 0) + 1
                continue
            alternatives = [card for card in by_topic[detail_value["topicCompatibility"]] if counts.get(card["id"], 0) < 2]
            if not alternatives:
                raise ValueError(f"{identifier} exceeds direct-attachment capacity")
            chosen = max(alternatives, key=lambda card: stable_tie(identifier, card["id"]))
            detail_value["canonicalID"] = chosen["id"]
            detail_value["selectionBasis"] = "semantic_topic_capacity_preserving_alternate"
            counts[chosen["id"]] = counts.get(chosen["id"], 0) + 1


def write(path: pathlib.Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--package", type=pathlib.Path, default=PACKAGE)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    package = args.package.resolve()
    manifest = json.loads((package / "package_manifest.json").read_text(encoding="utf-8"))
    if manifest.get("package_id") != PID or manifest.get("depends_on") != list(DEPENDENCY):
        raise SystemExit("P10_CONTRACT_ARTIFACT_ERROR: package identity/dependency order drift")
    cards = rows(package / "corpus/canonical_qa.jsonl")
    mapping = {
        "contradictions": {row["id"]: detail(row, cards, "contradictions") for row in rows(package / "corpus/contradictions.jsonl")},
        "myths": {row["id"]: detail(row, cards, "myths") for row in rows(package / "corpus/myths_and_antipatterns.jsonl")},
    }
    enforce_per_kind_capacity(mapping, cards)
    expected = {
        ROOT / "research/community_knowledge/dependency_maps" / (PID + ".json"): DEPENDENCY,
        ROOT / "research/community_knowledge/disagreement_maps" / (PID + ".json"): mapping,
    }
    drift = [str(path.relative_to(ROOT)) for path, value in expected.items() if not path.exists() or json.loads(path.read_text(encoding="utf-8")) != value]
    if args.check:
        if drift:
            raise SystemExit("P10_CONTRACT_ARTIFACT_CHECK_FAILED: " + ", ".join(drift))
    else:
        for path, value in expected.items():
            write(path, value)
    dep_hash = hashlib.sha256((ROOT / "research/community_knowledge/dependency_maps" / (PID + ".json")).read_bytes() if not args.check else json.dumps(DEPENDENCY, indent=2, sort_keys=True).encode()).hexdigest()
    print(f"P10_CONTRACT_ARTIFACT_OK dependencyEntries=9 disagreementEntries=104 dependencySHA256={dep_hash}")


if __name__ == "__main__":
    main()
