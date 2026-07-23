#!/usr/bin/env python3
"""Build TrackSmith's bounded abstract musician-language advisory catalog.

The reviewed ontology is the human-auditable source. Generated Swift contains
only TrackSmith-authored synthesis and explicit provenance identifiers. These
entries are advisory professional-practice hypotheses: they cannot become DSP,
host actions, measurements, or authority.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import pathlib


ROOT = pathlib.Path(__file__).resolve().parents[2]
DEFAULT_INPUT = ROOT / "research/knowledge/PRODUCTION_LANGUAGE_ONTOLOGY.json"
DEFAULT_OUTPUT = (
    ROOT
    / "packages/ProductionIntelligence/Sources/ProductionIntelligence/AbstractMusicianLanguageKnowledge.generated.swift"
)
EXPECTED_SCHEMA = "tracksmith.production-language-ontology.v2"
EXPECTED_ENTRY_COUNT = 14

VALID_SOURCE_TYPES = {
    "vocal",
    "vocalBus",
    "drums",
    "drumBus",
    "bass",
    "guitar",
    "keyboard",
    "synth",
    "fullMix",
}
VALID_TERMS = {
    "warm", "bright", "dark", "clear", "muddy", "boxy", "harsh", "sibilant",
    "punchy", "aggressive", "intimate", "distant", "polished", "raw", "wide",
    "narrow", "energetic", "smooth", "controlled", "dynamic", "vintage", "modern",
    "airy", "thin", "boomy", "tight", "soft", "forward", "lowEndWeight",
    "pickAttack", "monoCompatibility", "cymbalHarshness",
}
VALID_STRATEGIES = {
    "subtractiveEQ",
    "additiveEQ",
    "dynamicEQOrDeEsser",
    "gentleCompression",
    "transientPreservingCompression",
    "parallelCompression",
    "saturation",
    "stereoWidth",
    "preserveWithoutProcessing",
    "clarification",
    "listeningComparison",
}
VALID_POLICIES = {
    "singleBoundedHypothesis",
    "multipleNamedHypotheses",
    "clarificationWhenMaterial",
    "nonDSPAdvisory",
}


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=pathlib.Path, default=DEFAULT_INPUT)
    parser.add_argument("--output", type=pathlib.Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--check", action="store_true")
    return parser.parse_args()


def sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def require_string_list(value: object, label: str) -> list[str]:
    if not isinstance(value, list) or not value or not all(
        isinstance(item, str) and item.strip() for item in value
    ):
        raise ValueError(f"{label} must be a non-empty string list")
    return value


def validate(payload: dict) -> list[dict]:
    if payload.get("schema_version") != EXPECTED_SCHEMA:
        raise ValueError(f"expected schema {EXPECTED_SCHEMA!r}")
    if not isinstance(payload.get("ontology_version"), str) or not payload["ontology_version"]:
        raise ValueError("ontology_version is missing")
    entries = payload.get("abstract_musician_language")
    if not isinstance(entries, list) or len(entries) != EXPECTED_ENTRY_COUNT:
        raise ValueError(
            f"expected {EXPECTED_ENTRY_COUNT} abstract language entries, got "
            f"{len(entries) if isinstance(entries, list) else 'non-list'}"
        )
    identifiers: set[str] = set()
    for entry in entries:
        identifier = entry.get("identifier")
        if not isinstance(identifier, str) or not identifier or identifier in identifiers:
            raise ValueError(f"invalid or duplicate identifier: {identifier!r}")
        identifiers.add(identifier)
        if not isinstance(entry.get("surface_form"), str) or not entry["surface_form"]:
            raise ValueError(f"{identifier}: missing surface_form")
        require_string_list(entry.get("aliases"), f"{identifier}.aliases")
        sources = set(require_string_list(
            entry.get("applicable_source_types"),
            f"{identifier}.applicable_source_types",
        ))
        if not sources <= VALID_SOURCE_TYPES:
            raise ValueError(f"{identifier}: invalid source types {sorted(sources - VALID_SOURCE_TYPES)}")
        terms = set(require_string_list(
            entry.get("canonical_candidate_terms"),
            f"{identifier}.canonical_candidate_terms",
        ))
        if not terms <= VALID_TERMS:
            raise ValueError(f"{identifier}: invalid terms {sorted(terms - VALID_TERMS)}")
        if entry.get("resolution_policy") not in VALID_POLICIES:
            raise ValueError(f"{identifier}: invalid resolution_policy")
        senses = entry.get("possible_senses")
        if not isinstance(senses, list) or not senses:
            raise ValueError(f"{identifier}: possible_senses must be non-empty")
        covered_sources: set[str] = set()
        for index, sense in enumerate(senses):
            prefix = f"{identifier}.possible_senses[{index}]"
            sense_sources = set(require_string_list(sense.get("source_types"), f"{prefix}.source_types"))
            if not sense_sources <= sources:
                raise ValueError(f"{prefix}: sense sources exceed entry applicability")
            covered_sources.update(sense_sources)
            if not isinstance(sense.get("interpretation"), str) or not sense["interpretation"]:
                raise ValueError(f"{prefix}: missing interpretation")
            require_string_list(
                sense.get("supporting_evidence_categories"),
                f"{prefix}.supporting_evidence_categories",
            )
            require_string_list(
                sense.get("contradictory_evidence"),
                f"{prefix}.contradictory_evidence",
            )
            strategies = set(require_string_list(
                sense.get("candidate_strategy_categories"),
                f"{prefix}.candidate_strategy_categories",
            ))
            if not strategies <= VALID_STRATEGIES:
                raise ValueError(f"{prefix}: unsupported strategies {sorted(strategies - VALID_STRATEGIES)}")
            require_string_list(
                sense.get("unsupported_or_non_dsp_considerations"),
                f"{prefix}.unsupported_or_non_dsp_considerations",
            )
        if covered_sources != sources:
            raise ValueError(f"{identifier}: missing source senses {sorted(sources - covered_sources)}")
        require_string_list(entry.get("preservation_risks"), f"{identifier}.preservation_risks")
        require_string_list(entry.get("provenance_refs"), f"{identifier}.provenance_refs")
        confidence = entry.get("confidence")
        if not isinstance(confidence, (int, float)) or not 0 <= confidence <= 1:
            raise ValueError(f"{identifier}: confidence must be in [0, 1]")
        if not isinstance(entry.get("prohibited_mapping"), str) or not entry["prohibited_mapping"]:
            raise ValueError(f"{identifier}: missing prohibited_mapping")
    return entries


def swift_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def swift_string_array(values: list[str]) -> str:
    return "[" + ", ".join(swift_string(value) for value in values) + "]"


def swift_case_set(values: list[str]) -> str:
    return "Set([" + ", ".join(f".{value}" for value in values) + "])"


def render(payload: dict, source_hash: str, entries: list[dict]) -> str:
    lines = [
        "// Generated by research/scripts/build-production-language-knowledge.py.",
        "// Do not edit by hand; update PRODUCTION_LANGUAGE_ONTOLOGY.json.",
        "",
        "public extension AbstractMusicianLanguageKnowledgeCatalog {",
        "    static let trackSmithV1 = AbstractMusicianLanguageKnowledgeCatalog(",
        f"        sourceSHA256: {swift_string(source_hash)},",
        f"        ontologyVersion: {swift_string(payload['ontology_version'])},",
        "        reviewStatus: .primaryRoleResearchDeepReadProductionSensesRemainHeuristic,",
        "        entries: [",
    ]
    for entry in entries:
        lines.extend([
            "            AbstractMusicianLanguageKnowledge(",
            f"                identifier: {swift_string(entry['identifier'])},",
            f"                surfaceForm: {swift_string(entry['surface_form'])},",
            f"                aliases: {swift_string_array(entry['aliases'])},",
            f"                applicableSourceTypes: {swift_case_set(entry['applicable_source_types'])},",
            f"                canonicalCandidateTerms: {swift_case_set(entry['canonical_candidate_terms'])},",
            f"                resolutionPolicy: .{entry['resolution_policy']},",
            "                possibleSenses: [",
        ])
        for sense in entry["possible_senses"]:
            lines.extend([
                "                    AbstractMusicianLanguageSense(",
                f"                        sourceTypes: {swift_case_set(sense['source_types'])},",
                f"                        interpretation: {swift_string(sense['interpretation'])},",
                "                        supportingEvidenceCategories: "
                f"{swift_string_array(sense['supporting_evidence_categories'])},",
                "                        contradictoryEvidence: "
                f"{swift_string_array(sense['contradictory_evidence'])},",
                "                        candidateStrategyCategories: "
                f"{swift_case_set(sense['candidate_strategy_categories'])},",
                "                        unsupportedOrNonDSPConsiderations: "
                f"{swift_string_array(sense['unsupported_or_non_dsp_considerations'])}",
                "                    ),",
            ])
        lines.extend([
            "                ],",
            f"                preservationRisks: {swift_string_array(entry['preservation_risks'])},",
            f"                provenanceReferences: {swift_string_array(entry['provenance_refs'])},",
            f"                confidence: {entry['confidence']:.2f},",
            f"                prohibitedMapping: {swift_string(entry['prohibited_mapping'])}",
            "            ),",
        ])
    lines.extend([
        "        ]",
        "    )",
        "}",
        "",
    ])
    return "\n".join(lines)


def main() -> int:
    args = arguments()
    payload = json.loads(args.input.read_text(encoding="utf-8"))
    entries = validate(payload)
    output = render(payload, sha256(args.input), entries)
    if args.check:
        if not args.output.exists() or args.output.read_text(encoding="utf-8") != output:
            raise SystemExit(f"generated file is stale: {args.output}")
        print(f"PRODUCTION_LANGUAGE_GENERATED_CHECK_OK entries={len(entries)}")
        return 0
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(output, encoding="utf-8")
    print(
        "PRODUCTION_LANGUAGE_GENERATED_OK "
        f"entries={len(entries)} sha256={sha256(args.input)} output={args.output}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
