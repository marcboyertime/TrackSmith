#!/usr/bin/env python3
"""Validate the TrackSmith Vocal + Quantization Q&A corpus package.

Standard-library only. This validates structure, references, split-file
consistency, review-state safety, minimum corpus size, and (when present)
manifest hashes. It does not claim that candidate production advice has
completed human or installed-Logic review.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Iterable


EXPECTED_REVIEW_STATE = "candidate_not_yet_human_reviewed"
MINIMUMS = {
    "canonical_total": 200,
    "vocal_canonical": 140,
    "quantization_canonical": 60,
    "utterances_total": 3000,
    "scenarios_total": 400,
    "sources_total": 25,
    "contradictions_total": 10,
}

CANONICAL_REQUIRED = {
    "id",
    "schema_version",
    "domain",
    "category",
    "subcategory",
    "title",
    "canonical_user_question",
    "natural_language_variants",
    "clarification_questions",
    "candidate_hypotheses",
    "recommended_first_experiment",
    "logic_pro_steps",
    "starting_points",
    "what_to_listen_for",
    "stop_rule",
    "undo_or_reset",
    "rationale",
    "tradeoffs_and_risks",
    "alternatives_if_wrong",
    "common_mistakes",
    "teaching_principle",
    "do_not_assume",
    "source_ids",
    "review_status",
    "tracksmith_domains",
    "copyright_handling",
}

SOURCE_REQUIRED = {
    "source_id",
    "title",
    "publisher",
    "url",
    "source_type",
    "evidence_tier",
    "access_status",
    "topics",
    "use",
    "limitations",
}

UTTERANCE_REQUIRED = {
    "utterance_id",
    "canonical_id",
    "domain",
    "category",
    "text",
    "intent",
    "source",
    "difficulty",
    "expected_action",
}

SCENARIO_REQUIRED = {
    "scenario_id",
    "canonical_id",
    "domain",
    "turns",
    "branch_kind",
    "evaluation_criteria",
}


class ValidationError(Exception):
    pass


def load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001
        raise ValidationError(f"{path}: invalid JSON: {exc}") from exc


def load_jsonl(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    try:
        text = path.read_text(encoding="utf-8")
    except Exception as exc:  # noqa: BLE001
        raise ValidationError(f"{path}: cannot read UTF-8: {exc}") from exc
    for line_number, raw in enumerate(text.splitlines(), start=1):
        line = raw.strip()
        if not line:
            continue
        try:
            row = json.loads(line)
        except Exception as exc:  # noqa: BLE001
            raise ValidationError(
                f"{path}:{line_number}: invalid JSON object: {exc}"
            ) from exc
        if not isinstance(row, dict):
            raise ValidationError(f"{path}:{line_number}: expected JSON object")
        rows.append(row)
    if not rows:
        raise ValidationError(f"{path}: contains no records")
    return rows


def require_fields(row: dict[str, Any], required: set[str], label: str) -> None:
    missing = sorted(required - row.keys())
    if missing:
        raise ValidationError(f"{label}: missing fields: {', '.join(missing)}")


def require_nonempty(value: Any, label: str) -> None:
    if value is None:
        raise ValidationError(f"{label}: value is null")
    if isinstance(value, str) and not value.strip():
        raise ValidationError(f"{label}: empty string")
    if isinstance(value, (list, dict)) and not value:
        raise ValidationError(f"{label}: empty collection")


def unique_ids(rows: Iterable[dict[str, Any]], key: str, label: str) -> set[str]:
    seen: set[str] = set()
    for index, row in enumerate(rows, start=1):
        identifier = row.get(key)
        if not isinstance(identifier, str) or not identifier.strip():
            raise ValidationError(f"{label}[{index}]: invalid {key}")
        if identifier in seen:
            raise ValidationError(f"{label}: duplicate {key}: {identifier}")
        seen.add(identifier)
    return seen


def walk_strings(value: Any, path: str = "$") -> Iterable[tuple[str, str]]:
    if isinstance(value, str):
        yield path, value
    elif isinstance(value, list):
        for index, item in enumerate(value):
            yield from walk_strings(item, f"{path}[{index}]")
    elif isinstance(value, dict):
        for key, item in value.items():
            yield from walk_strings(item, f"{path}.{key}")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def ids(rows: Iterable[dict[str, Any]], key: str) -> set[str]:
    return {str(row[key]) for row in rows}


def validate(root: Path, verify_hashes: bool = True) -> dict[str, int]:
    corpus = root / "corpus"
    research = root / "research"
    integration = root / "integration"

    required_files = [
        root / "README.md",
        corpus / "canonical_qa.jsonl",
        corpus / "vocal_production_canonical.jsonl",
        corpus / "quantization_timing_canonical.jsonl",
        corpus / "user_utterances.jsonl",
        corpus / "vocal_user_utterances.jsonl",
        corpus / "quantization_user_utterances.jsonl",
        corpus / "multiturn_scenarios.jsonl",
        research / "source_registry.jsonl",
        research / "contradictions.jsonl",
        research / "taxonomy.json",
        integration / "tracksmith_claim_candidates.jsonl",
        integration / "tracksmith_strategy_candidates.jsonl",
        integration / "logic_procedure_candidates.jsonl",
        integration / "CODEX_HANDOFF.md",
        integration / "TRACKSMITH_IMPORT_PLAN.md",
        integration / "REVIEW_CHECKLIST.md",
    ]
    for path in required_files:
        if not path.is_file():
            raise ValidationError(f"missing required file: {path.relative_to(root)}")
        if path.stat().st_size == 0:
            raise ValidationError(f"empty required file: {path.relative_to(root)}")

    canonical = load_jsonl(corpus / "canonical_qa.jsonl")
    vocal = load_jsonl(corpus / "vocal_production_canonical.jsonl")
    quant = load_jsonl(corpus / "quantization_timing_canonical.jsonl")
    utterances = load_jsonl(corpus / "user_utterances.jsonl")
    vocal_utterances = load_jsonl(corpus / "vocal_user_utterances.jsonl")
    quant_utterances = load_jsonl(corpus / "quantization_user_utterances.jsonl")
    scenarios = load_jsonl(corpus / "multiturn_scenarios.jsonl")
    sources = load_jsonl(research / "source_registry.jsonl")
    contradictions = load_jsonl(research / "contradictions.jsonl")
    claims = load_jsonl(integration / "tracksmith_claim_candidates.jsonl")
    strategies = load_jsonl(integration / "tracksmith_strategy_candidates.jsonl")
    procedures = load_jsonl(integration / "logic_procedure_candidates.jsonl")

    canonical_ids = unique_ids(canonical, "id", "canonical")
    vocal_ids = unique_ids(vocal, "id", "vocal")
    quant_ids = unique_ids(quant, "id", "quantization")
    utterance_ids = unique_ids(utterances, "utterance_id", "utterances")
    scenario_ids = unique_ids(scenarios, "scenario_id", "scenarios")
    source_ids = unique_ids(sources, "source_id", "sources")
    unique_ids(contradictions, "id", "contradictions")
    unique_ids(claims, "id", "claim candidates")
    unique_ids(strategies, "id", "strategy candidates")
    unique_ids(procedures, "id", "procedure candidates")

    if vocal_ids & quant_ids:
        raise ValidationError("vocal and quantization canonical subsets overlap")
    if vocal_ids | quant_ids != canonical_ids:
        missing = sorted(canonical_ids - (vocal_ids | quant_ids))
        extra = sorted((vocal_ids | quant_ids) - canonical_ids)
        raise ValidationError(
            f"canonical split mismatch; missing={missing[:5]}, extra={extra[:5]}"
        )

    expected_vocal_ids = {
        row["id"] for row in canonical if row.get("domain") == "vocal_production"
    }
    expected_quant_ids = {
        row["id"]
        for row in canonical
        if row.get("domain") == "quantization_and_timing"
    }
    if vocal_ids != expected_vocal_ids:
        raise ValidationError("vocal split does not match domain labels")
    if quant_ids != expected_quant_ids:
        raise ValidationError("quantization split does not match domain labels")
    if canonical_ids != expected_vocal_ids | expected_quant_ids:
        unknown = sorted(
            canonical_ids - (expected_vocal_ids | expected_quant_ids)
        )
        raise ValidationError(f"unknown canonical domains: {unknown[:5]}")

    source_use_count: Counter[str] = Counter()
    utterance_count: Counter[str] = Counter()
    scenario_count: Counter[str] = Counter()

    for row in canonical:
        label = f"canonical[{row.get('id', '?')}]"
        require_fields(row, CANONICAL_REQUIRED, label)
        for field in (
            "title",
            "canonical_user_question",
            "natural_language_variants",
            "clarification_questions",
            "candidate_hypotheses",
            "recommended_first_experiment",
            "logic_pro_steps",
            "what_to_listen_for",
            "stop_rule",
            "undo_or_reset",
            "rationale",
            "teaching_principle",
            "source_ids",
            "tracksmith_domains",
        ):
            require_nonempty(row.get(field), f"{label}.{field}")
        if row["review_status"] != EXPECTED_REVIEW_STATE:
            raise ValidationError(
                f"{label}: unsafe review_status {row['review_status']!r}; "
                f"expected {EXPECTED_REVIEW_STATE!r}"
            )
        experiment = row["recommended_first_experiment"]
        if not isinstance(experiment, dict):
            raise ValidationError(f"{label}: first experiment must be an object")
        for field in ("summary", "why_this_first", "action", "scope"):
            require_nonempty(experiment.get(field), f"{label}.experiment.{field}")
        if len(row["clarification_questions"]) < 1:
            raise ValidationError(f"{label}: needs a clarification question")
        if len(row["candidate_hypotheses"]) < 2:
            raise ValidationError(f"{label}: needs competing hypotheses")
        if len(row["logic_pro_steps"]) < 2:
            raise ValidationError(f"{label}: needs at least two Logic steps")
        if len(row["what_to_listen_for"]) < 1:
            raise ValidationError(f"{label}: needs listening cues")
        for sid in row["source_ids"]:
            if sid not in source_ids:
                raise ValidationError(f"{label}: unresolved source_id {sid}")
            source_use_count[sid] += 1

        # Protect against accidental raw-page ingestion or giant quotations.
        for string_path, text in walk_strings(row):
            if len(text) > 4000:
                raise ValidationError(
                    f"{label}{string_path}: string exceeds 4,000 characters"
                )
            if "\n\n\n\n" in text:
                raise ValidationError(
                    f"{label}{string_path}: suspicious long block formatting"
                )

    for row in sources:
        label = f"source[{row.get('source_id', '?')}]"
        require_fields(row, SOURCE_REQUIRED, label)
        for field in ("title", "publisher", "url", "source_type", "evidence_tier"):
            require_nonempty(row.get(field), f"{label}.{field}")
        if row["evidence_tier"] not in {"A", "B", "C"}:
            raise ValidationError(f"{label}: invalid evidence tier")
        if not str(row["url"]).startswith(("https://", "http://")):
            raise ValidationError(f"{label}: invalid URL")

    for row in utterances:
        label = f"utterance[{row.get('utterance_id', '?')}]"
        require_fields(row, UTTERANCE_REQUIRED, label)
        cid = row["canonical_id"]
        if cid not in canonical_ids:
            raise ValidationError(f"{label}: unresolved canonical_id {cid}")
        utterance_count[cid] += 1
        require_nonempty(row["text"], f"{label}.text")
        if len(row["text"]) > 800:
            raise ValidationError(f"{label}: unexpectedly long utterance")

    expected_vocal_utterance_ids = {
        row["utterance_id"]
        for row in utterances
        if row.get("domain") == "vocal_production"
    }
    expected_quant_utterance_ids = {
        row["utterance_id"]
        for row in utterances
        if row.get("domain") == "quantization_and_timing"
    }
    if ids(vocal_utterances, "utterance_id") != expected_vocal_utterance_ids:
        raise ValidationError("vocal utterance split mismatch")
    if ids(quant_utterances, "utterance_id") != expected_quant_utterance_ids:
        raise ValidationError("quantization utterance split mismatch")
    if expected_vocal_utterance_ids | expected_quant_utterance_ids != utterance_ids:
        raise ValidationError("unknown utterance domain or split omission")

    for cid in canonical_ids:
        if utterance_count[cid] < 8:
            raise ValidationError(
                f"canonical[{cid}]: only {utterance_count[cid]} utterances"
            )

    for row in scenarios:
        label = f"scenario[{row.get('scenario_id', '?')}]"
        require_fields(row, SCENARIO_REQUIRED, label)
        cid = row["canonical_id"]
        if cid not in canonical_ids:
            raise ValidationError(f"{label}: unresolved canonical_id {cid}")
        scenario_count[cid] += 1
        if not isinstance(row["turns"], list) or len(row["turns"]) < 4:
            raise ValidationError(f"{label}: needs at least four turns")
        roles = [turn.get("role") for turn in row["turns"] if isinstance(turn, dict)]
        if "user" not in roles or "assistant_expected_behavior" not in roles:
            raise ValidationError(f"{label}: missing user/assistant behavior turns")
        if len(row["evaluation_criteria"]) < 3:
            raise ValidationError(f"{label}: insufficient evaluation criteria")

    for cid in canonical_ids:
        if scenario_count[cid] < 2:
            raise ValidationError(
                f"canonical[{cid}]: only {scenario_count[cid]} scenarios"
            )

    for row in contradictions:
        label = f"contradiction[{row.get('id', '?')}]"
        for field in (
            "id",
            "topic",
            "position_a",
            "position_b",
            "what_decides",
            "tutor_behavior",
            "source_ids",
        ):
            require_nonempty(row.get(field), f"{label}.{field}")
        if len(row["source_ids"]) < 1:
            raise ValidationError(f"{label}: must reference at least one source")
        for sid in row["source_ids"]:
            if sid not in source_ids:
                raise ValidationError(f"{label}: unresolved source_id {sid}")

    for collection_name, rows in (
        ("claim", claims),
        ("strategy", strategies),
        ("procedure", procedures),
    ):
        mapped: Counter[str] = Counter()
        for row in rows:
            cid = row.get("canonicalQAID")
            if cid not in canonical_ids:
                raise ValidationError(
                    f"{collection_name}[{row.get('id', '?')}]: "
                    f"unresolved canonicalQAID {cid}"
                )
            mapped[cid] += 1
            for source_key in ("sourceIDs", "supportingSourceIDs"):
                for sid in row.get(source_key, []):
                    if sid not in source_ids:
                        raise ValidationError(
                            f"{collection_name}[{row.get('id', '?')}]: "
                            f"unresolved source {sid}"
                        )
        if set(mapped) != canonical_ids:
            missing = sorted(canonical_ids - set(mapped))
            raise ValidationError(
                f"{collection_name} candidates missing canonical rows: {missing[:5]}"
            )

    counts = {
        "canonical_total": len(canonical),
        "vocal_canonical": len(vocal),
        "quantization_canonical": len(quant),
        "utterances_total": len(utterances),
        "scenarios_total": len(scenarios),
        "sources_total": len(sources),
        "contradictions_total": len(contradictions),
        "claim_candidates": len(claims),
        "strategy_candidates": len(strategies),
        "procedure_candidates": len(procedures),
    }
    for key, minimum in MINIMUMS.items():
        if counts[key] < minimum:
            raise ValidationError(
                f"{key}: expected at least {minimum}, got {counts[key]}"
            )

    unused_sources = sorted(source_ids - set(source_use_count))
    if unused_sources:
        raise ValidationError(
            f"source registry contains unreferenced sources: {unused_sources}"
        )

    taxonomy = load_json(research / "taxonomy.json")
    if not isinstance(taxonomy, dict):
        raise ValidationError("research/taxonomy.json must be an object")

    manifest_path = root / "manifest.json"
    if verify_hashes and manifest_path.exists():
        manifest = load_json(manifest_path)
        file_entries = manifest.get("files")
        if not isinstance(file_entries, list):
            raise ValidationError("manifest.json: files must be a list")
        for entry in file_entries:
            relative = entry.get("path")
            expected = entry.get("sha256")
            size = entry.get("bytes")
            if not relative or not expected:
                raise ValidationError("manifest.json: malformed file entry")
            path = root / relative
            if not path.is_file():
                raise ValidationError(f"manifest file missing: {relative}")
            actual = sha256(path)
            if actual != expected:
                raise ValidationError(
                    f"manifest hash mismatch: {relative}: {actual} != {expected}"
                )
            if size is not None and path.stat().st_size != size:
                raise ValidationError(f"manifest size mismatch: {relative}")

    return counts


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "package_root",
        nargs="?",
        type=Path,
        default=Path(__file__).resolve().parents[1],
    )
    parser.add_argument(
        "--skip-hashes",
        action="store_true",
        help="Validate content but do not verify manifest hashes.",
    )
    args = parser.parse_args()
    root = args.package_root.resolve()
    try:
        counts = validate(root, verify_hashes=not args.skip_hashes)
    except ValidationError as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1

    print("PASS: TrackSmith corpus package is structurally valid.")
    for key in sorted(counts):
        print(f"  {key}: {counts[key]}")
    print(
        "NOTE: structural validation does not promote candidate knowledge "
        "to reviewed or trusted status."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
