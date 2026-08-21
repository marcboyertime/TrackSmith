#!/usr/bin/env python3
"""Repository-owned, read-only trust gate for stable corpus packages.

Incoming package scripts and schemas are data, never executable authority.  This
validator deliberately reads only the verified package bytes and the repository's
stable-contract rules before the CAS stager is allowed to copy anything.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
import pathlib
import re
import shutil
import sqlite3
import stat
import sys
import tempfile

import community_corpus_import as trusted

ROOT = pathlib.Path(__file__).resolve().parents[2]
COMMUNITY = ROOT / "research/community_knowledge"
REGISTRY = COMMUNITY / "package_registry.json"
SOURCE = ROOT / "research/knowledge/general-tutor-source-registry.json"
QUEUE = ROOT / "research/knowledge/general-tutor-review-queue.json"

DATA_FILES = {
    "canonical_qa": "corpus/canonical_qa.jsonl",
    "user_utterances": "corpus/user_utterances.jsonl",
    "multiturn_scenarios": "corpus/multiturn_scenarios.jsonl",
    "retrieval_evaluations": "corpus/retrieval_evaluations.jsonl",
    "contradictions": "corpus/contradictions.jsonl",
    "myths_and_antipatterns": "corpus/myths_and_antipatterns.jsonl",
    "sources": "sources/source_registry.jsonl",
    "provenance": "sources/provenance_manifest.jsonl",
    "claim_candidates": "knowledge_candidates/claims.jsonl",
    "strategy_candidates": "knowledge_candidates/strategies.jsonl",
    "logic_procedure_candidates": "knowledge_candidates/logic_procedures.jsonl",
}
TEST_FILES = {
    "retrievalTests": "tests/retrieval_cases.jsonl",
    "integrityCases": "tests/integrity_cases.jsonl",
}
REQUIRED_TABLES = set(DATA_FILES) | {"packages"}
TRUSTED_FTS_TABLES = {
    "canonical_qa_fts", "canonical_qa_fts_config", "canonical_qa_fts_content",
    "canonical_qa_fts_data", "canonical_qa_fts_docsize", "canonical_qa_fts_idx",
}
ID_PATTERN = re.compile(r"^[a-zA-Z0-9][a-zA-Z0-9._-]*$")
REVIEW = "candidate_not_yet_human_reviewed"
SOURCE_CLASSES = {
    "official_documentation", "primary_research", "professional_practice",
    "specialist_discussion", "product_documentation", "community_pattern",
    "community_anecdote",
}


class PreflightError(ValueError):
    pass


def fail(message: str) -> None:
    raise PreflightError(message)


def sha(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def repository_tree_sha(root: pathlib.Path) -> tuple[int, str]:
    """The stager's byte-tree protocol, kept local so incoming tools never run."""
    records: list[tuple[str, bytes]] = []
    for base, directories, names in os.walk(root, followlinks=False):
        for name in names:
            path = pathlib.Path(base) / name
            if path.is_symlink() or not path.is_file(): fail("unsafe tree entry")
            records.append((path.relative_to(root).as_posix(), path.read_bytes()))
    digest = hashlib.sha256()
    for relative, value in sorted(records): digest.update(b"FILE\0" + relative.encode() + b"\0" + value)
    return len(records), digest.hexdigest()


def validate_pinned_artifacts(incoming: pathlib.Path, dependency_map: pathlib.Path, manifest: dict, archive: pathlib.Path | None = None) -> None:
    pid = manifest.get("package_id")
    spec = trusted.STABLE_CONTRACT_SPECS[pid]
    if not (spec.get("archiveRequired") or pid == "tracksmith-corpus-009-gain-staging-bus-processing-loudness"): return
    label = "stable package " + str(spec["number"])
    if sha(incoming / "package_manifest.json") != spec["manifestSHA256"]: fail(label + " manifest pin drift")
    if sha(incoming / "PACKAGE_SHA256SUMS.txt") != spec["checksumSHA256"]: fail(label + " checksum manifest pin drift")
    count, tree = repository_tree_sha(incoming)
    expected_count = 47 if spec.get("integrationManifestReconciliation") or spec["number"] == 10 else 46
    if count != expected_count or tree != spec["treeSHA256"]: fail(label + " tree pin drift")
    if sha(dependency_map) != spec["dependencySHA256"]: fail(label + " dependency-map pin drift")
    if archive is None or archive.is_symlink() or not archive.is_file() or sha(archive) != spec["archiveSHA256"]: fail(label + " archive pin drift")
    # Stable packages that explicitly require an archive bind both the archive
    # bytes and its adjacent publisher checksum. Do not make this package-ID
    # specific: P12 introduced the guard, while later stable contracts carry
    # the same archive-sidecar requirement declaratively.
    if spec.get("archiveRequired") and spec.get("archiveSHA256"):
        sidecar = archive.with_name(archive.name + ".sha256")
        if sidecar.is_symlink() or not sidecar.is_file(): fail(label + " archive sidecar missing or unsafe")
        if spec.get("sidecarSHA256") and sha(sidecar) != spec["sidecarSHA256"]: fail(label + " archive sidecar file pin drift")
        matches = re.findall(r"(?<![0-9a-f])[0-9a-f]{64}(?![0-9a-f])", sidecar.read_text(encoding="utf-8").lower())
        if matches != [spec["archiveSHA256"]]: fail(label + " archive sidecar pin drift")
    if spec.get("integrationManifestReconciliation"):
        integration = incoming / "integration/integration_manifest.json"
        if sha(integration) != spec["integrationManifestSHA256"]: fail(label + " integration manifest pin drift")


P10_OBSERVED_STATUS_PARTITIONS = {
    "review_state": {"candidate_discovery_only", "candidate_not_yet_human_reviewed", "candidate_reviewed_documentary", "candidate_reviewed_professional_practice"},
    "native_review_state": {"candidate_discovery_only", "candidate_not_yet_human_reviewed", "candidate_reviewed_documentary", "candidate_reviewed_professional_practice"},
    "original_review_state": {"candidate_discovery_only", "candidate_procedure_synthesis", "candidate_reviewed_documentary", "candidate_reviewed_professional_practice", "community_and_professional_disagreement", "derived_myth_correction", "derived_synthesis", "owner_supplied_example_language", "synthetic_exact_retrieval_fixture"},
    "original_verification_status": {"candidate_generated_from_registered_sources", "deterministic_fixture_alias", "literal_user_example_preserved", "source_metadata_registered", "source_span_or_documentary_metadata_registered"},
    "logic_verification_status": {"candidate_unverified_on_installed_logic", "not_applicable_to_source"},
    "runtime_eligibility": {"excluded_from_runtime", "retrieval_candidate", "source_reference_only", "test_only"},
}


def validate_observed_status_contract(incoming: pathlib.Path, pid: str, data: dict[str, list[dict]], tests: dict[str, list[dict]]) -> None:
    """Fail closed on all observed raw status values, not the incomplete input lists."""
    integration = load_json(incoming / "integration/integration_manifest.json")
    expected_integration_contract = "tracksmith-corpus-package" if pid == trusted.P15_ID else "tracksmith-corpus-integration-manifest"
    if not isinstance(integration, dict) or integration.get("contract") != expected_integration_contract or integration.get("contract_version") != "1.0":
        fail(pid + " integration contract drift")
    rows = [row for values in data.values() for row in values] + [row for values in tests.values() for row in values]
    expected_contract = trusted.STABLE_CONTRACT_SPECS[pid].get("observedStatusContract", P10_OBSERVED_STATUS_PARTITIONS)
    for field, expected in expected_contract.items():
        observed = {row[field] for row in rows if field in row}
        if observed != expected:
            fail(pid + " observed status partition drift: " + field)
    declared = set(integration.get("original_review_states", [])) | set(integration.get("original_verification_statuses", []))
    observed_value=trusted.STABLE_CONTRACT_SPECS[pid].get("observedStatusContract")
    if observed_value is True:
        omitted = {"owner_supplied_example_language", "synthetic_exact_retrieval_fixture", "deterministic_fixture_alias", "literal_user_example_preserved"}
        if not omitted <= (set().union(*expected_contract.values()) - declared):
            fail(pid + " non-exhaustive integration declaration contract drift")
    elif not set().union(*expected_contract.values()) >= declared:
        fail(pid + " declared status escapes observed contract")
    try:
        trusted.integration_contract_reconciliation(pid, incoming)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        fail(str(error))


def validate_standards_map(path: pathlib.Path, data: dict[str, list[dict]]) -> None:
    mapping = load_json(path)
    if not isinstance(mapping, dict) or set(mapping) != {"standards"} or not isinstance(mapping["standards"], dict): fail("standards map shape drift")
    expected = {f"pkg009.source.{number:06d}" for number in range(41, 51)}
    if set(mapping["standards"]) != expected: fail("standards map coverage drift")
    cards = {row["id"]: row for row in data["canonical_qa"]}
    sources = {row["id"]: row for row in data["sources"]}
    for source_id, value in mapping["standards"].items():
        if sources.get(source_id, {}).get("evidence_class") != "primary_research" or not isinstance(value, dict) or set(value) != {"canonicalIDs", "rationale"}:
            fail("standards source classification/map detail drift")
        ids = value["canonicalIDs"]
        if not isinstance(ids, list) or not ids or len(ids) != len(set(ids)) or any(identifier not in cards or cards[identifier]["domain"] != "clipping_limiting_loudness" for identifier in ids) or not isinstance(value["rationale"], str) or not value["rationale"].strip():
            fail("standards source/card/topic reachability drift")
    if not {"pkg009.qa.000281", "pkg009.qa.000282", "pkg009.qa.000283"} <= set(mapping["standards"]["pkg009.source.000043"]["canonicalIDs"]):
        fail("EBU Tech 3341 metering coverage drift")


def load_json(path: pathlib.Path) -> object:
    if path.is_symlink() or not path.is_file():
        fail("missing or unsafe JSON input: " + str(path))
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        fail("invalid JSON " + path.name + ": " + str(error))


def load_rows(path: pathlib.Path) -> list[dict]:
    if path.is_symlink() or not path.is_file():
        fail("missing or unsafe JSONL input: " + str(path))
    values: list[dict] = []
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if not line.strip():
            continue
        try:
            value = json.loads(line)
        except json.JSONDecodeError as error:
            fail(f"invalid JSONL {path.name}:{number}: {error}")
        if not isinstance(value, dict):
            fail(f"JSONL record is not an object: {path.name}:{number}")
        values.append(value)
    return values


def verify_package_inventory(incoming: pathlib.Path) -> None:
    """No-follow checksum inventory over every incoming package byte."""
    sums = incoming / "PACKAGE_SHA256SUMS.txt"
    if sums.is_symlink() or not sums.is_file():
        fail("checksum inventory missing or unsafe")
    actual: set[str] = set()
    def onerror(error: OSError) -> None:
        fail("package inventory walk error: " + str(error))
    for base, directories, names in os.walk(incoming, followlinks=False, onerror=onerror):
        base_path = pathlib.Path(base)
        for name in list(directories):
            entry = base_path / name
            mode = entry.lstat().st_mode
            if stat.S_ISLNK(mode) or not stat.S_ISDIR(mode):
                fail("package contains unsafe directory entry: " + entry.relative_to(incoming).as_posix())
        for name in names:
            entry = base_path / name
            mode = entry.lstat().st_mode
            relative = entry.relative_to(incoming).as_posix()
            if stat.S_ISLNK(mode) or not stat.S_ISREG(mode):
                fail("package contains unsafe file entry: " + relative)
            if entry != sums:
                actual.add(relative)
    listed: dict[str, str] = {}
    for line in sums.read_text(encoding="utf-8").splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})  ([^\\/].*)", line)
        if not match:
            fail("checksum inventory line shape drift")
        digest, relative = match.groups()
        pure = pathlib.PurePosixPath(relative)
        if pure.is_absolute() or ".." in pure.parts or relative in listed:
            fail("checksum inventory path drift")
        entry = incoming.joinpath(*pure.parts)
        if entry.is_symlink() or not entry.is_file() or incoming not in entry.resolve().parents:
            fail("checksum inventory unsafe entry: " + relative)
        if sha(entry) != digest:
            fail("package SHA inventory drift: " + relative)
        listed[relative] = digest
    if set(listed) != actual:
        fail("checksum inventory does not equal package files")


def require_string(row: dict, key: str, context: str, minimum: int = 1) -> str:
    value = row.get(key)
    if not isinstance(value, str) or len(value.strip()) < minimum:
        fail(f"{context}: required string {key} missing")
    return value


def require_list(row: dict, key: str, context: str, minimum: int = 0) -> list:
    value = row.get(key)
    if not isinstance(value, list) or len(value) < minimum:
        fail(f"{context}: required list {key} missing")
    return value


def require_ids(values: object, context: str, minimum: int = 1) -> list[str]:
    if not isinstance(values, list) or len(values) < minimum or any(not isinstance(item, str) or not ID_PATTERN.fullmatch(item) for item in values):
        fail(context + ": invalid ID list")
    return values


def validate_schema(name: str, rows: list[dict], pid: str) -> None:
    """Small repository schema: required fields/types/enums cannot be relaxed by input."""
    for index, row in enumerate(rows, start=1):
        context = f"{name}[{index}]"
        identifier = require_string(row, "id", context)
        if not ID_PATTERN.fullmatch(identifier):
            fail(context + ": invalid id pattern")
        if name != "sources" or "package_id" in row:
            if require_string(row, "package_id", context) != pid:
                fail(context + ": package_id drift")
        if name in {"canonical_qa", "user_utterances", "multiturn_scenarios", "retrieval_evaluations", "contradictions", "myths_and_antipatterns", "provenance", "claim_candidates", "strategy_candidates", "logic_procedure_candidates"}:
            if require_string(row, "review_state", context) != REVIEW:
                fail(context + ": candidate review state drift")
        if name == "canonical_qa":
            for key in ("domain", "subdomain", "topic", "title", "canonical_question", "direct_answer", "recommended_first_experiment", "key_distinction", "teaching_principle", "user_intent"):
                require_string(row, key, context)
            require_ids(row.get("source_ids"), context)
            for key in ("retrieval_tags", "clarification_questions", "competing_hypotheses", "tradeoffs", "evidence_needed"):
                require_list(row, key, context)
            textual_hypotheses = trusted.STABLE_CONTRACT_SPECS[pid].get("competingHypothesesText")
            if textual_hypotheses:
                valid_hypotheses = all(isinstance(value, str) and value.strip() for value in row["competing_hypotheses"])
            else:
                valid_hypotheses = all(isinstance(value, dict) and isinstance(value.get("label"), str) and isinstance(value.get("description"), str) for value in row["competing_hypotheses"])
            if not valid_hypotheses:
                fail(context + ": competing hypothesis shape drift")
            if trusted.STABLE_CONTRACT_SPECS[pid].get("nonProcessingField"):
                require_list(row, "non_processing_possibilities", context)
            guidance = row.get("logic_guidance")
            if not isinstance(guidance, dict):
                fail(context + ": logic_guidance must be object")
            guidance_keys = ("listen_for", "undo") if trusted.STABLE_CONTRACT_SPECS[pid].get("strategyDerivedStopRule") else ("listen_for", "stop_condition", "undo")
            for key in guidance_keys:
                require_string(guidance, key, context + ".logic_guidance")
            if row.get("evidence_class") != "derived_synthesis":
                fail(context + ": canonical evidence class drift")
        elif name == "user_utterances":
            require_string(row, "canonical_qa_id", context); require_string(row, "text", context)
            require_string(row, "variant_type", context); require_list(row, "retrieval_tags", context)
        elif name == "multiturn_scenarios":
            require_string(row, "canonical_qa_id", context); require_string(row, "scenario_type", context)
            messages = require_list(row, "messages", context, 2)
            for message in messages:
                if not isinstance(message, dict) or message.get("role") not in {"user", "assistant_expected"}:
                    fail(context + ": scenario message role drift")
                require_string(message, "text", context + ".messages")
            expected_roles = ["user" if offset % 2 == 0 else "assistant_expected" for offset in range(len(messages))]
            if [message["role"] for message in messages] != expected_roles:
                fail(context + ": scenario roles must alternate user/assistant_expected")
            for key in ("expected_behaviors", "forbidden_behaviors"):
                values = require_list(row, key, context, 1)
                if any(not isinstance(value, str) or not value.strip() for value in values):
                    fail(context + ": scenario behavior shape drift")
        elif name == "retrieval_evaluations":
            require_string(row, "canonical_qa_id", context); require_string(row, "query", context); require_string(row, "evaluation_type", context)
            require_ids(row.get("expected_canonical_ids"), context)
            forbidden = require_ids(row.get("forbidden_canonical_ids"), context, 0)
            if set(forbidden) & set(row["expected_canonical_ids"]):
                fail(context + ": expected/forbidden overlap")
        elif name in {"contradictions", "myths_and_antipatterns"}:
            for key in (("topic", "position_a", "position_b", "what_decides") if name == "contradictions" else ("myth", "correction", "safer_principle")):
                require_string(row, key, context)
            require_ids(row.get("source_ids"), context)
        elif name == "sources":
            required_source_keys = ("title", "publisher_or_community", "canonical_url", "access_mode")
            for key in required_source_keys:
                require_string(row, key, context)
            if not trusted.STABLE_CONTRACT_SPECS[pid].get("sourceRetrievedAtOptional"):
                require_string(row, "retrieved_at", context)
            if row.get("version_scope") is not None and (not isinstance(row["version_scope"], str) or not row["version_scope"].strip()):
                fail(context + ": version_scope must be null or nonempty string")
            if row.get("evidence_class") not in SOURCE_CLASSES:
                fail(context + ": unsupported source evidence class")
            require_list(row, "limitations", context)
        elif name == "provenance":
            require_string(row, "canonical_qa_id", context); require_ids(row.get("source_ids"), context)
            if not any(isinstance(row.get(key), str) and row[key].strip() for key in ("transformation", "derivation")):
                fail(context + ": provenance transformation/derivation missing")
        elif name == "claim_candidates":
            require_string(row, "canonical_qa_id", context); require_string(row, "claim_text", context); require_ids(row.get("source_ids"), context)
        elif name == "strategy_candidates":
            for key in ("canonical_qa_id", "label", "recommended_first_experiment", "stop_rule", "undo", "what_to_listen_for"):
                require_string(row, key, context)
            require_ids(row.get("source_ids"), context); require_list(row, "tradeoffs", context)
        elif name == "logic_procedure_candidates":
            for key in ("canonical_qa_id", "title", "listen_for", "location", "risk", "undo", "logic_version_scope"):
                require_string(row, key, context)
            require_ids(row.get("source_ids"), context)
            if row.get("verification_status") != "candidate_unverified_on_installed_logic" or row.get("execution_authority") is not False:
                fail(context + ": procedure authority/verification drift")
            if not isinstance(row.get("steps"), list) or not row["steps"]:
                fail(context + ": procedure steps shape drift")


def validate_retrieval_tests(rows: list[dict], name: str, canonical_rows: list[dict]) -> None:
    canonical_ids = {row["id"] for row in canonical_rows}
    canonical_topics = {row["topic"] for row in canonical_rows}
    canonical_domain_pairs = {(row["domain"], row["subdomain"]) for row in canonical_rows}
    for index, row in enumerate(rows, start=1):
        context = f"{name}[{index}]"
        require_string(row, "id", context)
        if name == "retrievalTests":
            require_string(row, "query", context)
            if "canonical_qa_id" in row and ("classification" in row or "retrieval_classification" in row):
                identifier = require_string(row, "canonical_qa_id", context)
                if identifier not in canonical_ids:
                    fail(context + ": classified canonical target does not resolve")
                classification = row.get("classification", row.get("retrieval_classification"))
                diagnostic = row.get("diagnostic_only")
                expected_top_1 = row.get("expected_top_1", row.get("retrieval_expectation") == "expected_top_1")
                permitted = {"exact_unique", "diagnostic_semantic_only", "diagnostic_multi_intent", "diagnostic_cross_domain_collision", "diagnostic_low_margin"}
                if classification not in permitted or not isinstance(diagnostic, bool) or not isinstance(expected_top_1, bool):
                    fail(context + ": classified retrieval shape drift")
                if (classification == "exact_unique") != (not diagnostic and expected_top_1):
                    fail(context + ": classified exact/diagnostic classification drift")
                if classification != "exact_unique" and (not diagnostic or expected_top_1):
                    fail(context + ": classified diagnostic classification drift")
                continue
            has_domains = isinstance(row.get("expected_domain"), str) and isinstance(row.get("expected_subdomain"), str)
            has_unique_subdomain = isinstance(row.get("expected_subdomain"), str) and sum(1 for item in canonical_rows if item.get("subdomain") == row["expected_subdomain"]) == 10
            has_topics = isinstance(row.get("expected_topics"), list) and bool(row["expected_topics"])
            has_ids = isinstance(row.get("expected_canonical_ids"), list) and bool(row["expected_canonical_ids"])
            if not (has_domains or has_unique_subdomain or has_topics or has_ids):
                fail(context + ": supplied retrieval expectation shape drift")
            if has_domains and (row["expected_domain"], row["expected_subdomain"]) not in canonical_domain_pairs:
                fail(context + ": supplied expected domain/subdomain does not resolve")
            if isinstance(row.get("expected_subdomain"), str) and not has_domains and not has_unique_subdomain:
                fail(context + ": supplied expected subdomain is not uniquely resolvable")
            if has_topics:
                if any(not isinstance(topic, str) or not topic.strip() for topic in row["expected_topics"]):
                    fail(context + ": supplied expected topic shape drift")
                if any(topic not in canonical_topics for topic in row["expected_topics"]):
                    fail(context + ": supplied expected topic does not resolve")
            if "expected_canonical_ids" in row:
                expected = require_ids(row["expected_canonical_ids"], context)
                forbidden = require_ids(row.get("forbidden_canonical_ids", []), context, 0)
                if set(expected) & set(forbidden):
                    fail(context + ": supplied expected/forbidden overlap")
                if not set(expected) <= canonical_ids or not set(forbidden) <= canonical_ids:
                    fail(context + ": supplied expected/forbidden canonical ID does not resolve")
        else:
            if not any(isinstance(row.get(key), str) and row[key].strip() for key in ("check", "assertion")):
                fail(context + ": integrity check/assertion missing")
            if "expected" in row and not isinstance(row["expected"], (str, int, float, bool, list, dict)):
                fail(context + ": integrity expected shape drift")
            if "expected" not in row and "assertion" not in row:
                fail(context + ": integrity expectation/assertion missing")


def validate_references(data: dict[str, list[dict]]) -> None:
    seen: dict[str, str] = {}
    for name, values in data.items():
        for row in values:
            identifier = row["id"]
            if identifier in seen:
                fail(f"duplicate ID {identifier} in {seen[identifier]} and {name}")
            seen[identifier] = name
    canonical = {row["id"] for row in data["canonical_qa"]}
    sources = {row["id"] for row in data["sources"]}
    for name, values in data.items():
        for row in values:
            for key in ("canonical_qa_id",):
                if key in row and row[key] not in canonical:
                    fail(f"{name}:{row['id']} dangling canonical reference")
            for key in ("canonical_id", "canonicalID"):
                if key in row and row[key] not in canonical:
                    fail(f"{name}:{row['id']} dangling canonical reference")
            for source_id in row.get("source_ids", []):
                if source_id not in sources:
                    fail(f"{name}:{row['id']} dangling source reference")
            for expected in row.get("expected_canonical_ids", []):
                if expected not in canonical:
                    fail(f"{name}:{row['id']} invalid expected canonical ID")
            for forbidden in row.get("forbidden_canonical_ids", []):
                if forbidden not in canonical:
                    fail(f"{name}:{row['id']} invalid forbidden canonical ID")


def validate_stable_contract(manifest: dict, pid: str, data: dict[str, list[dict]]) -> None:
    spec = trusted.STABLE_CONTRACT_SPECS[pid]
    expected = {
        "canonical_qa": spec["canonical"], "user_utterances": spec["utterances"],
        "multiturn_scenarios": spec["scenarios"], "retrieval_evaluations": spec["retrieval"],
        "contradictions": spec["contradictions"], "myths_and_antipatterns": spec["myths"],
        "sources": spec["sources"], "provenance": spec["canonical"],
        "claim_candidates": spec["canonical"], "strategy_candidates": spec["canonical"],
        "logic_procedure_candidates": spec["canonical"],
    }
    if manifest.get("package_number") != spec["number"] or manifest.get("review_state") != REVIEW or manifest.get("logic_procedure_status") != "candidate_unverified_on_installed_logic":
        fail("stable contract package/status drift")
    if any(len(data[name]) != count for name, count in expected.items()):
        fail("stable contract table-count drift")
    if manifest.get("record_counts") != expected:
        fail("stable contract manifest count drift")
    scenario_counts: dict[int, int] = {}
    for row in data["multiturn_scenarios"]:
        scenario_counts[len(row["messages"])] = scenario_counts.get(len(row["messages"]), 0) + 1
    if scenario_counts != spec["scenarioMessageCounts"]:
        fail("stable contract scenario-message count drift")
    canonical_ids = {row["id"] for row in data["canonical_qa"]}
    for name in ("provenance", "claim_candidates", "strategy_candidates", "logic_procedure_candidates"):
        if {row["canonical_qa_id"] for row in data[name]} != canonical_ids:
            fail("stable contract canonical coverage drift: " + name)
    if spec.get("strategyDerivedStopRule"):
        strategies = {row["canonical_qa_id"]: row for row in data["strategy_candidates"]}
        if any(not isinstance(strategies[identifier].get("stop_rule"), str) or not strategies[identifier]["stop_rule"].strip() for identifier in canonical_ids):
            fail("stable contract strategy-derived stop-rule drift")
    source_counts: dict[str, int] = {}
    source_statuses: dict[str, int] = {}
    for row in data["sources"]:
        source_counts[row["evidence_class"]] = source_counts.get(row["evidence_class"], 0) + 1
        source_statuses[row["review_state"]] = source_statuses.get(row["review_state"], 0) + 1
    if source_counts != spec["sourceClassCounts"]:
        fail("stable contract source-class partition drift")
    if not spec.get("sourceMatrix") and source_statuses != {"candidate_reviewed_documentary": spec["documentary"], REVIEW: spec["sources"] - spec["documentary"]}:
        fail("stable contract documentary/unreviewed source status drift")
    if spec.get("sourceMatrix"):
        matrix: dict[str, int] = {}
        for row in data["sources"]:
            key = "|".join((row["evidence_class"], row["review_state"], row["access_mode"]))
            matrix[key] = matrix.get(key, 0) + 1
        if matrix != spec["sourceMatrix"]: fail("stable contract source class/status/access matrix drift")
        if spec.get("sourceHandlingByAccessContract") and spec.get("includePrimaryResearch"):
            primary = [row for row in data["sources"] if row["evidence_class"] == "primary_research"]
            if len(primary) != 2 or any(row["review_state"] != "candidate_reviewed_primary_research" or row["access_mode"] != "searchDiscoveryOnly" for row in primary):
                fail("P12 primary-research provenance/access boundary drift")
        for field, rows, key in (("domains", data["canonical_qa"], "domain"), ("scenarioDomains", data["multiturn_scenarios"], "domain"), ("scenarioTypes", data["multiturn_scenarios"], "scenario_type"), ("retrievalTypes", data["retrieval_evaluations"], "evaluation_type")):
            observed: dict[str, int] = {}
            for row in rows: observed[row[key]] = observed.get(row[key], 0) + 1
            if observed != spec[field]: fail("stable contract " + field + " distribution drift")
        subdomains: dict[str, int] = {}
        for row in data["canonical_qa"]: subdomains[row["subdomain"]] = subdomains.get(row["subdomain"], 0) + 1
        if subdomains != manifest.get("canonical_subdomain_counts") or set(subdomains.values()) != {10}: fail("stable contract scenario subdomain distribution drift")
        if pid == "tracksmith-corpus-009-gain-staging-bus-processing-loudness":
            validate_p9_numeric_policy(manifest, data)


def validate_p9_numeric_policy(manifest: dict, data: dict[str, list[dict]]) -> None:
    prohibited = ("Universal gain targets", "bus chains", "limiter ceilings", "LUFS targets", "clipping amounts", "analog-model calibration")
    if not any(all(term in value for term in prohibited) for value in manifest.get("not_intended_use", []) if isinstance(value, str)): fail("P9 numeric manifest prohibition drift")
    for row in data["canonical_qa"]:
        limitations = row.get("limitations", [])
        if not isinstance(limitations, list) or not any("not universal presets" in value for value in limitations if isinstance(value, str)):
            fail("P9 numeric canonical limitation drift")


def validate_sqlite(incoming: pathlib.Path, manifest: dict, data: dict[str, list[dict]]) -> None:
    database = incoming / "database/corpus.sqlite"
    if database.is_symlink() or not database.is_file():
        fail("SQLite corpus missing or unsafe")
    uri = database.resolve().as_uri() + "?mode=ro&immutable=1"
    try:
        connection = sqlite3.connect(uri, uri=True)
        try:
            connection.row_factory = sqlite3.Row
            connection.execute("PRAGMA query_only=ON")
            if connection.execute("PRAGMA query_only").fetchone()[0] != 1:
                fail("SQLite immutable read-only connection drift")
            if connection.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
                fail("SQLite integrity check failed")
            # The FTS tables are an exact SQLite-managed whitelist, never a
            # prefix exemption that could conceal an untrusted table.
            names = {row[0] for row in connection.execute("SELECT name FROM sqlite_master WHERE type='table'")}
            if names != REQUIRED_TABLES | TRUSTED_FTS_TABLES:
                fail("SQLite required table drift")
            for table, values in data.items():
                count = connection.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
                if count != len(values):
                    fail(f"SQLite row count drift: {table}")
                database_rows = {
                    identifier: json.loads(record)
                    for identifier, record in connection.execute(f"SELECT id, record_json FROM {table}")
                }
                json_rows = {row["id"]: row for row in values}
                if database_rows != json_rows:
                    fail(f"SQLite JSON record parity drift: {table}")
                for database_row in connection.execute(f"SELECT * FROM {table}"):
                    record = database_rows[database_row["id"]]
                    for column in database_row.keys():
                        if column in {"record_json", "source_ids_json"}:
                            continue
                        if column in record and database_row[column] != record[column]:
                            fail(f"SQLite indexed-column parity drift: {table}.{column}")
                    if "source_ids_json" in database_row.keys() and json.loads(database_row["source_ids_json"]) != record.get("source_ids"):
                        fail(f"SQLite source ID parity drift: {table}")
            package_rows = connection.execute("SELECT package_id, manifest_json FROM packages").fetchall()
            if len(package_rows) != 1 or package_rows[0][0] != manifest["package_id"] or json.loads(package_rows[0][1]) != manifest:
                fail("SQLite package manifest parity drift")
        finally:
            connection.close()
    except sqlite3.Error as error:
        fail("SQLite read-only validation failed: " + str(error))


def normalized_map(rows: list[dict], text_key: str, canonical_key: str) -> dict[str, set[str]]:
    values: dict[str, set[str]] = {}
    for row in rows:
        normalized = trusted.normalized_runtime_identity(row[text_key])
        values.setdefault(normalized, set()).add(row[canonical_key])
    return values


def validate_accounting(pid: str, data: dict[str, list[dict]], tests: dict[str, list[dict]] | None = None) -> tuple[int, int, int, int]:
    if trusted.STABLE_CONTRACT_SPECS[pid].get("classifiedRetrievalTests"):
        if tests is None: fail("P10 accounting requires supplied fixture partition")
        try: trusted.classified_fixture_accounting(tests["retrievalTests"], {row["id"] for row in data["canonical_qa"]}, trusted.STABLE_CONTRACT_SPECS[pid])
        except ValueError as error: fail(str(error))
        spec = trusted.STABLE_CONTRACT_SPECS[pid]
        if spec.get("fixtureMode") == "exact_subset":
            raw = normalized_map(data["user_utterances"], "text", "canonical_qa_id")
            if any(len(value) > 1 for value in raw.values()): fail("ambiguous normalized utterance alias")
            retrieval = data["retrieval_evaluations"]
            lexical = [row for row in retrieval if raw.get(trusted.normalized_runtime_identity(row["query"]), set()) == set(row["expected_canonical_ids"])]
            by_class = {kind: sum(row.get("retrieval_classification") == kind for row in lexical) for kind in spec["retrievalTypes"]}
            if len(lexical) != spec["rawNormalizedUniqueMatchCount"] or len(retrieval) - len(lexical) != spec["rawNormalizedNonMatchCount"] or by_class != spec["diagnosticNormalizedExactByClassification"]:
                fail("stable-contract raw normalized lexical accounting drift")
            if by_class["diagnostic_semantic_only"] != spec["diagnosticNormalizedExactCollisionCount"] or sum(value for key, value in by_class.items() if key != "exact_unique") != spec["diagnosticNormalizedExactCollisionCount"]:
                fail("stable-contract diagnostic normalized lexical collision drift")
            return len(lexical), len(retrieval) - len(lexical), spec["runtimeNormalizedUniqueMatchCount"], spec["runtimeNormalizedNonMatchCount"]
        return spec["rawExactCount"], spec["rawNonExactCount"], spec["runtimeExactCount"], spec["runtimeNonExactCount"]
    utterances = data["user_utterances"]
    retrieval = data["retrieval_evaluations"]
    raw = normalized_map(utterances, "text", "canonical_qa_id")
    if any(len(value) > 1 for value in raw.values()):
        fail("ambiguous normalized utterance alias")
    projected = [{**row, "text": trusted.clean_utterance(row["text"], row["canonical_qa_id"])} for row in utterances]
    safe = normalized_map(projected, "text", "canonical_qa_id")
    if any(len(value) > 1 for value in safe.values()):
        fail("ambiguous runtime-safe normalized utterance alias")
    raw_exact = sum(raw.get(trusted.normalized_runtime_identity(row["query"]), set()) == set(row["expected_canonical_ids"]) for row in retrieval)
    safe_exact = sum(safe.get(trusted.normalized_runtime_identity(row["query"]), set()) == set(row["expected_canonical_ids"]) for row in retrieval)
    raw_nonexact, safe_nonexact = len(retrieval) - raw_exact, len(retrieval) - safe_exact
    spec = trusted.STABLE_CONTRACT_SPECS.get(pid)
    if spec and (raw_exact != spec["rawExactCount"] or raw_nonexact != spec["rawNonExactCount"] or safe_exact != spec.get("runtimeExactCount", raw_exact) or safe_nonexact != spec.get("runtimeNonExactCount", raw_nonexact)):
        fail("stable contract exact-accounting drift")
    return raw_exact, raw_nonexact, safe_exact, safe_nonexact


def validate_runtime_projection(pid: str, manifest: dict, manifest_sha: str, data: dict[str, list[dict]], disagreement_path: pathlib.Path | None) -> None:
    """Safety-scan the same trusted projection used by the shipping importer."""
    forbidden = trusted.FORBIDDEN_RUNTIME_KEYS | {"steps", "location"}
    def scan(value: object, path: str) -> None:
        if isinstance(value, dict):
            for key, child in value.items():
                if str(key).lower().replace("-", "_") in forbidden:
                    fail("forbidden procedure/runtime field: " + path + "." + str(key))
                scan(child, path + "." + str(key))
        elif isinstance(value, list):
            for index, child in enumerate(value): scan(child, f"{path}[{index}]")
    for procedure in data["logic_procedure_candidates"]:
        scan({key: value for key, value in procedure.items() if key not in {"steps", "location"}}, "procedure")
    mapping = load_json(disagreement_path) if disagreement_path is not None else None
    try: trusted.assert_runtime_safe(trusted.stable_runtime_projection(pid, manifest, manifest_sha, data, mapping))
    except ValueError as error: fail(str(error))
    if trusted.STABLE_CONTRACT_SPECS[pid].get("runtimeExcludeCardStatusKeys"):
        try: trusted.assert_runtime_status_free(trusted.stable_runtime_projection(pid, manifest, manifest_sha, data, mapping))
        except ValueError as error: fail(str(error))
    if fragments := trusted.STABLE_CONTRACT_SPECS[pid].get("runtimeFieldExclusionFragments"):
        try: trusted.assert_runtime_field_exclusions(trusted.stable_runtime_projection(pid, manifest, manifest_sha, data, mapping), fragments)
        except ValueError as error: fail(str(error))
    if pid == "tracksmith-corpus-009-gain-staging-bus-processing-loudness":
        runtime = trusted.stable_runtime_projection(pid, manifest, manifest_sha, data, mapping)
        if any(card.get("numericGuidancePolicy") != trusted.STABLE_CONTRACT_SPECS[pid]["numericGuidancePolicy"] for card in runtime["canonicalCards"]):
            fail("P9 runtime numeric policy drift")


def validate_retrieval_bijection(pid: str, data: dict[str, list[dict]], tests: dict[str, list[dict]]) -> None:
    """Reconcile full fixtures and capability-declared exact subsets."""
    if not trusted.STABLE_CONTRACT_SPECS[pid].get("classifiedRetrievalTests"):
        return
    def key(row: dict) -> tuple[str, str, str]:
        target=row.get("canonical_qa_id")
        if not isinstance(target,str):
            expected=row.get("expected_canonical_ids", [])
            target=expected[0] if isinstance(expected,list) and len(expected)==1 else None
        return (str(row.get("query")), str(target), str(row.get("retrieval_classification",row.get("classification"))))
    evaluations={key(row) for row in data["retrieval_evaluations"]}
    fixtures={key(row) for row in tests["retrievalTests"]}
    if len(evaluations) != len(data["retrieval_evaluations"]) or len(fixtures) != len(tests["retrievalTests"]):
        fail(pid + " retrieval evaluation/test exact bijection drift")
    if trusted.STABLE_CONTRACT_SPECS[pid].get("fixtureMode") == "exact_subset":
        exact={key(row) for row in data["retrieval_evaluations"] if row.get("retrieval_classification",row.get("classification")) == "exact_unique"}
        if fixtures != exact:
            fail(pid + " retrieval exact-subset fixture key drift")
    elif evaluations != fixtures:
        fail(pid + " retrieval evaluation/test exact bijection drift")


def validate_disagreement_map(path: pathlib.Path, data: dict[str, list[dict]]) -> None:
    mapping = load_json(path)
    if not isinstance(mapping, dict) or set(mapping) != {"contradictions", "myths"}:
        fail("disagreement map shape drift")
    cards = {row["id"]: row for row in data["canonical_qa"]}
    sources = {row["id"] for row in data["sources"]}
    pid = next(iter(cards.values()))["package_id"]
    spec = trusted.STABLE_CONTRACT_SPECS[pid]
    buckets = {identifier: {"contradictions": 0, "myths": 0} for identifier in cards}
    for name, source_name, cap in (("contradictions", "contradictions", spec["contradictionCap"]), ("myths", "myths_and_antipatterns", spec["mythCap"])):
        values = mapping[name]
        if not isinstance(values, dict) or set(values) != {row["id"] for row in data[source_name]}:
            fail("disagreement map coverage drift: " + name)
        for row in data[source_name]:
            detail = values[row["id"]]
            statement = row["topic"] if name == "contradictions" else row["myth"]
            if spec.get("directSemanticMap"):
                expected_keys = {"canonicalID", "topicCompatibility", "rationale"} | ({"selectionBasis"} if spec.get("disagreementSelectionBasis") else set())
                if not isinstance(detail, dict) or set(detail) != expected_keys:
                    fail("disagreement map detail shape drift: " + row["id"])
                target = detail["canonicalID"]
                rationale = detail["rationale"]
                prefix = "Direct semantic attachment:" if spec.get("recordSpecificRationale") else "Direct semantic attachment"
                if target not in cards or detail["topicCompatibility"] != cards[target]["topic"] or not isinstance(rationale, str) or not rationale.startswith(prefix) or (spec.get("recordSpecificRationale") and statement not in rationale):
                    fail("disagreement semantic/topic/rationale drift: " + row["id"])
                if spec.get("disagreementSelectionBasis") and detail["selectionBasis"] not in {"source_provenance_plus_topic_terms", "source_provenance_with_explicit_low_lexical_margin", "semantic_topic_without_card_source_overlap", "semantic_topic_capacity_preserving_alternate"}:
                    fail("disagreement selection basis drift: " + row["id"])
            else:
                if not isinstance(detail, str):
                    fail("legacy disagreement target shape drift: " + row["id"])
                target = detail
                if target not in cards:
                    fail("legacy disagreement target reachability drift: " + row["id"])
            if any(source_id not in sources for source_id in row["source_ids"]):
                fail("disagreement provenance source drift: " + row["id"])
            buckets[target][name] += 1
            if buckets[target][name] > cap:
                fail("disagreement per-kind cap drift")
    if any(values["contradictions"] + values["myths"] > spec["combinedCap"] for values in buckets.values()):
        fail("disagreement combined cap drift")


def registered_ids(excluding: pathlib.Path | None = None) -> set[str]:
    registry = load_json(REGISTRY)
    if not isinstance(registry, dict) or registry.get("contract") != "tracksmith-community-package-registry" or registry.get("version") != "1.0":
        fail("registry contract/version drift")
    values: set[str] = set()
    for entry in registry.get("packages", []):
        package_id, relative = entry.get("package_id"), entry.get("path")
        if not isinstance(package_id, str) or not isinstance(relative, str) or package_id in values:
            fail("registry package identity drift")
        location = (ROOT / relative).resolve()
        if ROOT.resolve() not in location.parents or not location.exists():
            fail("registry path missing: " + package_id)
        manifest = location / "package_manifest.json"
        if not manifest.is_file():
            manifest = location / "manifest.json"
        if not manifest.is_file() or sha(manifest) != entry.get("package_manifest_sha256"):
            fail("registry manifest hash drift: " + package_id)
        if excluding is None or location != excluding.resolve():
            values.add(package_id)
    return values


def prior_registered_raw_ids(incoming: pathlib.Path, pid: str) -> set[str]:
    registry = load_json(REGISTRY)
    incoming_manifest_sha = sha(incoming / "package_manifest.json")
    values: set[str] = set()
    for entry in registry["packages"]:
        package_id, relative = entry["package_id"], entry["path"]
        # Same package and exact manifest is a read-only audit of installed
        # bytes, not a new package collision. Every other registered raw tree
        # remains part of the global namespace comparison.
        if package_id == pid and entry.get("package_manifest_sha256") == incoming_manifest_sha:
            continue
        location = (ROOT / relative).resolve()
        for path in location.rglob("*.jsonl"):
            relative_parts = path.relative_to(location).parts
            if "tools" in relative_parts or "schemas" in relative_parts:
                continue
            for row in load_rows(path):
                identifier = row.get("id")
                if isinstance(identifier, str):
                    values.add(identifier)
    return values


def is_identical_registered_audit(incoming: pathlib.Path, pid: str) -> bool:
    """Only a byte-identical registered package may share generated projections."""
    incoming_manifest_sha = sha(incoming / "package_manifest.json")
    registry = load_json(REGISTRY)
    return any(
        entry.get("package_id") == pid and entry.get("package_manifest_sha256") == incoming_manifest_sha
        for entry in registry.get("packages", [])
    )


def validate(incoming: pathlib.Path, dependency_map: pathlib.Path, disagreement_map: pathlib.Path | None, strict_stage: bool, standards_map: pathlib.Path | None = None, archive: pathlib.Path | None = None) -> tuple[str, tuple[int, int, int, int]]:
    if incoming.is_symlink() or not incoming.is_dir():
        fail("incoming package root missing or unsafe")
    incoming = incoming.resolve()
    verify_package_inventory(incoming)
    manifest = load_json(incoming / "package_manifest.json")
    if not isinstance(manifest, dict):
        fail("manifest is not an object")
    pid = manifest.get("package_id")
    if manifest.get("package_contract") != "tracksmith-corpus-package" or manifest.get("contract_version") != "1.0" or not isinstance(pid, str) or not isinstance(manifest.get("package_number"), int):
        fail("incoming stable contract identity drift")
    if pid not in trusted.STABLE_CONTRACT_SPECS:
        fail("unknown stable contract package")
    validate_pinned_artifacts(incoming, dependency_map, manifest, archive)
    data = {name: load_rows(incoming / relative) for name, relative in DATA_FILES.items()}
    for name, values in data.items():
        validate_schema(name, values, pid)
    tests = {name: load_rows(incoming / relative) for name, relative in TEST_FILES.items()}
    for name, values in tests.items():
        validate_retrieval_tests(values, name, data["canonical_qa"])
    counts = manifest.get("record_counts")
    if not isinstance(counts, dict) or any(counts.get(name) != len(values) for name, values in data.items()):
        fail("manifest JSONL inventory drift")
    if trusted.STABLE_CONTRACT_SPECS[pid].get("observedStatusContract"):
        validate_observed_status_contract(incoming, pid, data, tests)
    validate_stable_contract(manifest, pid, data)
    validate_references(data)
    validate_sqlite(incoming, manifest, data)
    accounting = validate_accounting(pid, data, tests)
    validate_retrieval_bijection(pid, data, tests)
    if strict_stage:
        if disagreement_map is None:
            fail("strict stage requires explicit disagreement map")
        validate_disagreement_map(disagreement_map, data)
        expected_map = trusted.STABLE_CONTRACT_SPECS[pid].get("disagreementSHA256")
        if expected_map is not None and sha(disagreement_map) != expected_map:
            fail(pid + " disagreement-map pin drift")
        if pid == "tracksmith-corpus-009-gain-staging-bus-processing-loudness":
            if archive is None: fail("P9 strict stage requires immutable archive pin")
            if standards_map is None: fail("P9 strict stage requires explicit standards map")
            validate_standards_map(standards_map, data)
    validate_runtime_projection(pid, manifest, sha(incoming / "package_manifest.json"), data, disagreement_map if strict_stage else None)
    mapping = load_json(dependency_map)
    if not isinstance(mapping, dict) or set(mapping) != set(manifest.get("depends_on", [])) or len(set(mapping.values())) != len(mapping):
        fail("dependency map must uniquely resolve every declared dependency")
    installed = registered_ids()
    if not set(mapping.values()) <= installed:
        fail("dependency map resolves unknown package")
    all_incoming_rows = [row for values in data.values() for row in values] + [row for values in tests.values() for row in values]
    incoming_id_list = [row["id"] for row in all_incoming_rows]
    if len(incoming_id_list) != len(set(incoming_id_list)):
        fail("duplicate incoming ID across corpus/test namespace")
    incoming_ids = set(incoming_id_list)
    existing_source_ids = {row.get("id") for row in load_json(SOURCE).get("sources", []) if row.get("id")}
    existing_queue_ids = {row.get("id") for row in load_json(QUEUE).get("candidates", []) if row.get("id")}
    runtime_ids: set[str] = set()
    for resource in (ROOT / "packages/ProductionTutor/Sources/ProductionTutor/Resources").glob("*.json"):
        value = load_json(resource)
        if isinstance(value, dict):
            runtime_ids |= {row.get("id") for row in value.get("canonicalCards", []) if isinstance(row, dict) and row.get("id")}
    raw_collisions = incoming_ids & prior_registered_raw_ids(incoming, pid)
    if raw_collisions:
        fail("incoming ID collision with prior registered raw package: " + sorted(raw_collisions)[0])
    # Registered identical packages are an audit case; foreign source/queue/runtime
    # collisions remain fatal.  The raw-tree check above still covers P1-P7.
    if not is_identical_registered_audit(incoming, pid) and incoming_ids & (existing_source_ids | existing_queue_ids | runtime_ids):
        fail("incoming ID collision with source/queue/runtime")
    labels=("rawNormalizedUnique","rawNormalizedNonMatch","runtimeNormalizedUnique","runtimeNormalizedNonMatch") if trusted.STABLE_CONTRACT_SPECS[pid].get("fixtureMode") == "exact_subset" else ("rawExact","rawNonExact","runtimeExact","runtimeNonExact")
    print("CORPUS_PREFLIGHT_COUNTS package=%s %s=%d %s=%d %s=%d %s=%d" % (pid, labels[0], accounting[0], labels[1], accounting[1], labels[2], accounting[2], labels[3], accounting[3]))
    return pid, accounting


def refresh_sums(root: pathlib.Path) -> None:
    sums = root / "PACKAGE_SHA256SUMS.txt"
    paths = sorted(path for path in root.rglob("*") if path.is_file() and path != sums)
    sums.write_text("".join(f"{sha(path)}  {path.relative_to(root).as_posix()}\n" for path in paths), encoding="utf-8")


def validate_generated_p9_projection(text: str) -> None:
    start, end = text.find('#"""'), text.rfind('"""#')
    if start < 0 or end < 0: fail("GeneralTutor generated projection unreadable")
    value = json.loads(text[start + 4:end])
    forbidden = ("pkg009.qa.", "pkg009.claim.", "pkg009.strategy.", "pkg009.procedure.", "pkg009.contradiction.", "pkg009.myth.")
    if any(token in text for token in forbidden): fail("GeneralTutor P9 advice leakage")
    if sum(str(row.get("id", "")).startswith("pkg009.source.") for row in value.get("sources", [])) != 95 or {key: len(value.get(key, [])) for key in ("claims", "strategies", "concepts", "contradictions")} != {"claims":458,"strategies":78,"concepts":12,"contradictions":2}:
        fail("GeneralTutor P9 source delta/non-source projection drift")


def p9_specific_self_test(incoming: pathlib.Path, dependency: pathlib.Path, disagreement: pathlib.Path, standards: pathlib.Path, archive: pathlib.Path | None) -> list[str]:
    """Named P9 guard tests. Pin tests exercise production order; content tests
    invoke the same validators after the real package has passed its pins."""
    manifest = load_json(incoming / "package_manifest.json"); data = {name: load_rows(incoming / relative) for name, relative in DATA_FILES.items()}
    expected: list[str] = []
    def expect(name: str, needle: str, operation) -> None:
        try: operation()
        except PreflightError as error:
            if needle not in str(error): fail(name + " wrong guard: " + str(error))
            expected.append(name); return
        fail(name + " accepted")
    with tempfile.TemporaryDirectory(prefix="tracksmith-p9-specific-") as temporary:
        root = pathlib.Path(temporary) / "package"; shutil.copytree(incoming, root); dep = pathlib.Path(temporary) / "dep.json"; shutil.copyfile(dependency, dep)
        (root / "package_manifest.json").write_text("{}", encoding="utf-8"); expect("artifact_manifest_pin_drift", "manifest pin", lambda: validate_p9_pins(root, dep, manifest))
        shutil.rmtree(root); shutil.copytree(incoming, root); (root / "PACKAGE_SHA256SUMS.txt").write_text("x", encoding="utf-8"); expect("artifact_checksum_manifest_pin_drift", "checksum manifest pin", lambda: validate_p9_pins(root, dep, manifest))
        shutil.rmtree(root); shutil.copytree(incoming, root); (root / "README.md").write_text("tree drift", encoding="utf-8"); expect("artifact_tree_pin_drift", "tree pin", lambda: validate_p9_pins(root, dep, manifest))
        shutil.rmtree(root); shutil.copytree(incoming, root); dep.write_text("{}", encoding="utf-8"); expect("dependency_map_pin_drift", "dependency-map pin", lambda: validate_p9_pins(root, dep, manifest))
        if archive is None: fail("P9 self-test requires archive")
        archive_copy=pathlib.Path(temporary)/"archive.zip"; shutil.copyfile(archive,archive_copy); archive_copy.write_bytes(b"archive drift"); expect("artifact_archive_pin_drift", "archive pin", lambda: validate_p9_pins(incoming, dependency, manifest, archive_copy))
    changed = copy.deepcopy(data); changed["sources"][0]["access_mode"] = "searchDiscoveryOnly"; expect("source_class_status_access_matrix_drift", "source class/status/access matrix", lambda: validate_stable_contract(manifest, "tracksmith-corpus-009-gain-staging-bus-processing-loudness", changed))
    def altered_standards(mutator):
        with tempfile.TemporaryDirectory(prefix="tracksmith-p9-standards-") as temporary:
            path = pathlib.Path(temporary) / "standards.json"; value = load_json(standards); mutator(value); path.write_text(json.dumps(value), encoding="utf-8"); return path, tempfile.TemporaryDirectory
    def standards_case(name, needle, mutator):
        with tempfile.TemporaryDirectory(prefix="tracksmith-p9-standards-") as temporary:
            path=pathlib.Path(temporary)/"map.json"; value=load_json(standards); mutator(value); path.write_text(json.dumps(value),encoding="utf-8"); expect(name, needle, lambda: validate_standards_map(path,data))
    standards_case("standards_map_missing_source", "coverage", lambda value: value["standards"].pop("pkg009.source.000041"))
    with tempfile.TemporaryDirectory(prefix="tracksmith-p9-standards-") as temporary:
        path=pathlib.Path(temporary)/"map.json"; shutil.copyfile(standards,path); changed=copy.deepcopy(data); next(row for row in changed["sources"] if row["id"]=="pkg009.source.000041")["evidence_class"]="official_documentation"; expect("standards_map_bad_source_class", "classification", lambda: validate_standards_map(path,changed))
    standards_case("standards_map_dangling_card", "reachability", lambda value: value["standards"]["pkg009.source.000041"].__setitem__("canonicalIDs", ["missing.card"]))
    standards_case("standards_map_bad_rationale_or_topic", "reachability", lambda value: value["standards"]["pkg009.source.000041"].__setitem__("rationale", ""))
    standards_case("standards_ebu3341_metering_reachability_missing", "EBU Tech 3341", lambda value: value["standards"]["pkg009.source.000043"].__setitem__("canonicalIDs", ["pkg009.qa.000281"]))
    bad=copy.deepcopy(manifest); bad["not_intended_use"]=[]; expect("numeric_manifest_prohibition_missing", "numeric manifest", lambda: validate_p9_numeric_policy(bad,data))
    changed=copy.deepcopy(data); changed["canonical_qa"][0]["limitations"]=[]; expect("numeric_canonical_policy_or_limitation_drift", "numeric canonical", lambda: validate_p9_numeric_policy(manifest,changed))
    for name,key,value,needle in (("scenario_message_distribution_drift","messages",[],"scenario-message count"),("scenario_type_distribution_drift","scenario_type","wrong","scenarioTypes distribution"),("scenario_domain_distribution_drift","domain","wrong","scenarioDomains distribution")):
        changed=copy.deepcopy(data); changed["multiturn_scenarios"][0][key]=value; expect(name, needle, lambda changed=changed: validate_stable_contract(manifest,"tracksmith-corpus-009-gain-staging-bus-processing-loudness",changed))
    changed=copy.deepcopy(data); changed["canonical_qa"][0]["subdomain"]="wrong"; expect("scenario_subdomain_distribution_drift", "subdomain distribution", lambda: validate_stable_contract(manifest,"tracksmith-corpus-009-gain-staging-bus-processing-loudness",changed))
    changed=copy.deepcopy(data); changed["retrieval_evaluations"][0]["evaluation_type"]="wrong"; expect("retrieval_type_distribution_drift", "retrievalTypes distribution", lambda: validate_stable_contract(manifest,"tracksmith-corpus-009-gain-staging-bus-processing-loudness",changed))
    changed=copy.deepcopy(data); changed["user_utterances"][-1]["text"]=changed["user_utterances"][0]["text"]; expect("exact_accounting_or_alias_drift", "ambiguous normalized", lambda: validate_accounting("tracksmith-corpus-009-gain-staging-bus-processing-loudness",changed))
    with tempfile.TemporaryDirectory(prefix="tracksmith-p9-disagree-") as temporary:
        path=pathlib.Path(temporary)/"map.json"; value=load_json(disagreement); target=next(iter(value["contradictions"].values()))["canonicalID"]
        for row in list(value["contradictions"].values())[:3]: row["canonicalID"]=target; row["topicCompatibility"]=next(x for x in data["canonical_qa"] if x["id"]==target)["topic"]
        path.write_text(json.dumps(value),encoding="utf-8"); expect("disagreement_cap_or_coverage_drift", "per-kind cap", lambda: validate_disagreement_map(path,data))
    baseline = ROOT / "research/community_knowledge/preservation_baselines/tracksmith-corpus-009-gain-staging-bus-processing-loudness.json"
    with tempfile.TemporaryDirectory(prefix="tracksmith-p9-preservation-") as temporary:
        path = pathlib.Path(temporary) / "baseline.json"; value = load_json(baseline); value["registryProjection"] = "bad"; path.write_text(json.dumps(value), encoding="utf-8")
        def verify_bad_baseline() -> None:
            try:
                trusted.verify_p9_preservation_baseline(path)
            except ValueError as error:
                raise PreflightError(str(error))
        expect("prior_preservation_baseline_drift", "P9 preservation baseline", verify_bad_baseline)
    generated=(ROOT/"packages/ProductionTutor/Sources/ProductionTutor/GeneralTutorKnowledge.generated.swift").read_text(); expect("GeneralTutor_pkg009_advice_leak", "advice leakage", lambda: validate_generated_p9_projection(generated+"pkg009.qa.000001")); expect("GeneralTutor_source_delta_not_exactly_95_or_non_source_projection_drift", "source delta", lambda: validate_generated_p9_projection(generated.replace("pkg009.source.000001", "notpkg009.source.000001", 1)))
    return expected


def self_test(incoming: pathlib.Path, dependency_map: pathlib.Path, disagreement_map: pathlib.Path, standards_map: pathlib.Path | None = None, archive: pathlib.Path | None = None) -> None:
    """Mutate only disposable copies; every effective corruption must fail closed."""
    cases: list[tuple[str, object]] = []
    selftest_manifest = load_json(incoming / "package_manifest.json")
    supports_two_axis = trusted.STABLE_CONTRACT_SPECS.get(selftest_manifest.get("package_id"), {}).get("fixtureMode") == "exact_subset"
    supplied_rows = load_rows(incoming / "tests/retrieval_cases.jsonl")
    p10_supplied_schema = bool(supplied_rows) and {"canonical_qa_id", "classification"}.issubset(supplied_rows[0])
    def json_mutation(relative: str, mutate):
        def action(root: pathlib.Path, mapping: pathlib.Path) -> None:
            path = root / relative; values = load_rows(path); before = copy.deepcopy(values); mutate(values)
            if values == before: fail("self-test JSON mutation made no row change: " + relative)
            path.write_text("".join(json.dumps(value, sort_keys=True) + "\n" for value in values), encoding="utf-8")
        return action
    def synced_json_mutation(relative: str, table: str, mutate, columns: tuple[str, ...] = ()):
        """Keep the disposable SQLite mirror coherent so projection guards run."""
        def action(root: pathlib.Path, mapping: pathlib.Path) -> None:
            path = root / relative
            values = load_rows(path)
            before = copy.deepcopy(values)
            mutate(values)
            if values == before: fail("self-test JSON mutation made no row change: " + relative)
            path.write_text("".join(json.dumps(value, sort_keys=True) + "\n" for value in values), encoding="utf-8")
            connection = sqlite3.connect(root / "database/corpus.sqlite")
            try:
                for row in values:
                    assignments = ["record_json=?"] + [column + "=?" for column in columns]
                    parameters = [json.dumps(row, sort_keys=True)] + [row[column] for column in columns] + [row["id"]]
                    connection.execute("UPDATE " + table + " SET " + ", ".join(assignments) + " WHERE id=?", parameters)
                connection.commit()
            finally:
                connection.close()
        return action
    def malformed_supplied_test(values):
        if p10_supplied_schema:
            values[0].pop("classification")
        else:
            values[0].pop("expected_domain", None) or values[0].pop("expected_subdomain", None)
    def diagnostic_expectation_mismatch(values):
        row = next((value for value in values if value.get("classification") != "exact_unique"), values[0])
        if row.get("classification") == "exact_unique":
            row["diagnostic_only"] = True
        else:
            row["expected_top_1"] = True
    cases.extend([
        ("duplicate_id", json_mutation("corpus/user_utterances.jsonl", lambda values: values.__setitem__(1, {**values[1], "id": values[0]["id"]}))),
        ("missing_required_field", json_mutation("corpus/canonical_qa.jsonl", lambda values: values[0].pop("title"))),
        ("dangling_canonical", json_mutation("corpus/user_utterances.jsonl", lambda values: values[0].__setitem__("canonical_qa_id", "missing.canonical"))),
        ("dangling_source", json_mutation("corpus/canonical_qa.jsonl", lambda values: values[0].__setitem__("source_ids", ["missing.source"]))),
        ("malformed_scenario", json_mutation("corpus/multiturn_scenarios.jsonl", lambda values: values[0].__setitem__("messages", [{"role": "bad", "text": "x"}]))),
        ("malformed_supplied_test", json_mutation("tests/retrieval_cases.jsonl", malformed_supplied_test)),
        ("duplicate_test_id", json_mutation("tests/retrieval_cases.jsonl", lambda values: values.__setitem__(1, {**values[1], "id": values[0]["id"]}))),
        ("test_data_id_collision", json_mutation("tests/retrieval_cases.jsonl", lambda values: values[0].__setitem__("id", load_rows(incoming / "corpus/canonical_qa.jsonl")[0]["id"]))),
        ("malformed_integrity_test", json_mutation("tests/integrity_cases.jsonl", lambda values: (values[0].pop("expected", None), values[0].pop("check", None), values[0].pop("assertion", None)))),
        ("ambiguous_normalized_alias", json_mutation("corpus/user_utterances.jsonl", lambda values: values[1].__setitem__("text", values[0]["text"]))),
        ("unsafe_runtime_projection", json_mutation("knowledge_candidates/logic_procedures.jsonl", lambda values: values[0].__setitem__("procedure_body", "never project this body"))),
        ("unsafe_teaching_principle", synced_json_mutation("corpus/canonical_qa.jsonl", "canonical_qa", lambda values: values[0].__setitem__("teaching_principle", "A procedure body must never ship."))),
        ("unsafe_retrieval_tag", synced_json_mutation("corpus/canonical_qa.jsonl", "canonical_qa", lambda values: values[0].__setitem__("retrieval_tags", ["procedure body leakage"]))),
        ("unsafe_disagreement_provenance", synced_json_mutation("corpus/contradictions.jsonl", "contradictions", lambda values: values[0].__setitem__("position_a", "A procedure body decides this."), ("position_a",))),
    ])
    if p10_supplied_schema:
        cases.extend([
            ("dangling_supplied_id", json_mutation("tests/retrieval_cases.jsonl", lambda values: values[0].__setitem__("canonical_qa_id", "missing.canonical"))),
            ("invalid_supplied_classification", json_mutation("tests/retrieval_cases.jsonl", lambda values: values[0].__setitem__("classification", "missing_classification"))),
            ("diagnostic_expectation_mismatch", json_mutation("tests/retrieval_cases.jsonl", diagnostic_expectation_mismatch)),
        ])
    else:
        cases.extend([
            ("dangling_supplied_id", json_mutation("tests/retrieval_cases.jsonl", lambda values: values[0].__setitem__("expected_canonical_ids", ["missing.canonical"]))),
            ("dangling_supplied_topic", json_mutation("tests/retrieval_cases.jsonl", lambda values: values[0].__setitem__("expected_topics", ["missing_topic"]))),
            ("dangling_supplied_domain", json_mutation("tests/retrieval_cases.jsonl", lambda values: values[0].__setitem__("expected_domain", "missing_domain"))),
        ])
    def corrupt_sqlite(root: pathlib.Path, mapping: pathlib.Path) -> None:
        database = root / "database/corpus.sqlite"; database.write_bytes(database.read_bytes()[:100])
    def sqlite_parity(root: pathlib.Path, mapping: pathlib.Path) -> None:
        database = root / "database/corpus.sqlite"; connection = sqlite3.connect(database)
        try: connection.execute("UPDATE canonical_qa SET title='parity drift' WHERE id=(SELECT id FROM canonical_qa LIMIT 1)"); connection.commit()
        finally: connection.close()
    def sqlite_extra_table(root: pathlib.Path, mapping: pathlib.Path) -> None:
        database = root / "database/corpus.sqlite"; connection = sqlite3.connect(database)
        try: connection.execute("CREATE TABLE untrusted_extra_table(id TEXT)"); connection.commit()
        finally: connection.close()
    def sqlite_fts_evil(root: pathlib.Path, mapping: pathlib.Path) -> None:
        database = root / "database/corpus.sqlite"; connection = sqlite3.connect(database)
        try: connection.execute("CREATE TABLE canonical_qa_fts_evil(id TEXT)"); connection.commit()
        finally: connection.close()
    def accounting_drift(root: pathlib.Path, mapping: pathlib.Path) -> None:
        path = root / "corpus/retrieval_evaluations.jsonl"; values = load_rows(path); values[0]["query"] = "intentionally non exact accounting drift"; path.write_text("".join(json.dumps(value, sort_keys=True) + "\n" for value in values), encoding="utf-8")
        database = root / "database/corpus.sqlite"; connection = sqlite3.connect(database)
        try:
            row = values[0]; connection.execute("UPDATE retrieval_evaluations SET query=?, record_json=? WHERE id=?", (row["query"], json.dumps(row, sort_keys=True), row["id"])); connection.commit()
        finally: connection.close()
    def p12_diagnostic_lexical_drift(root: pathlib.Path, mapping: pathlib.Path) -> None:
        path = root / "corpus/retrieval_evaluations.jsonl"; values = load_rows(path)
        row = next(value for value in values if value.get("retrieval_classification") == "diagnostic_semantic_only")
        row["query"] = "intentionally non exact diagnostic lexical accounting drift"
        path.write_text("".join(json.dumps(value, sort_keys=True) + "\n" for value in values), encoding="utf-8")
        connection = sqlite3.connect(root / "database/corpus.sqlite")
        try:
            connection.execute("UPDATE retrieval_evaluations SET query=?, record_json=? WHERE id=?", (row["query"], json.dumps(row, sort_keys=True), row["id"])); connection.commit()
        finally: connection.close()
    def bad_map(root: pathlib.Path, mapping: pathlib.Path) -> None:
        value = load_json(mapping); key = next(iter(value["contradictions"])); value["contradictions"][key]["topicCompatibility"] = "wrong-topic"; mapping.write_text(json.dumps(value, sort_keys=True), encoding="utf-8")
    def prior_raw_collision(root: pathlib.Path, mapping: pathlib.Path) -> None:
        prior = ROOT / "research/community_knowledge/packages/tracksmith-corpus-007-phase-polarity-stereo-imaging-panning/corpus/user_utterances.jsonl"
        prior_id = load_rows(prior)[0]["id"]
        path = root / "corpus/user_utterances.jsonl"; values = load_rows(path); old_id = values[0]["id"]; values[0]["id"] = prior_id
        path.write_text("".join(json.dumps(value, sort_keys=True) + "\n" for value in values), encoding="utf-8")
        connection = sqlite3.connect(root / "database/corpus.sqlite")
        try:
            connection.execute("UPDATE user_utterances SET id=?, record_json=? WHERE id=?", (prior_id, json.dumps(values[0], sort_keys=True), old_id)); connection.commit()
        finally: connection.close()
    def wrong_message_count(root: pathlib.Path, mapping: pathlib.Path) -> None:
        path = root / "corpus/multiturn_scenarios.jsonl"; values = load_rows(path); values[0]["messages"] = values[0]["messages"][:-1]
        path.write_text("".join(json.dumps(value, sort_keys=True) + "\n" for value in values), encoding="utf-8")
        connection = sqlite3.connect(root / "database/corpus.sqlite")
        try:
            connection.execute("UPDATE multiturn_scenarios SET record_json=? WHERE id=?", (json.dumps(values[0], sort_keys=True), values[0]["id"])); connection.commit()
        finally: connection.close()
    def source_partition_drift(root: pathlib.Path, mapping: pathlib.Path) -> None:
        path = root / "sources/source_registry.jsonl"; values = load_rows(path); values[0]["evidence_class"] = "community_anecdote"
        path.write_text("".join(json.dumps(value, sort_keys=True) + "\n" for value in values), encoding="utf-8")
        connection = sqlite3.connect(root / "database/corpus.sqlite")
        try:
            connection.execute("UPDATE sources SET evidence_class=?, record_json=? WHERE id=?", (values[0]["evidence_class"], json.dumps(values[0], sort_keys=True), values[0]["id"])); connection.commit()
        finally: connection.close()
    def disagreement_overflow(root: pathlib.Path, mapping: pathlib.Path) -> None:
        value = load_json(mapping)
        targets: dict[str, list[str]] = {}
        for identifier, detail in value["contradictions"].items(): targets.setdefault(detail["canonicalID"], []).append(identifier)
        target = max(targets, key=lambda identifier: len(targets[identifier]))
        canonical = {row["id"]: row for row in load_rows(root / "corpus/canonical_qa.jsonl")}
        donors = [identifier for identifier, detail in value["contradictions"].items() if detail["canonicalID"] != target][:3]
        for donor in donors:
            value["contradictions"][donor]["canonicalID"] = target
            value["contradictions"][donor]["topicCompatibility"] = canonical[target]["topic"]
        mapping.write_text(json.dumps(value, sort_keys=True), encoding="utf-8")
    cases.extend([("corrupt_sqlite", corrupt_sqlite), ("sqlite_json_parity", sqlite_parity), ("sqlite_extra_table", sqlite_extra_table), ("sqlite_fts_evil", sqlite_fts_evil), ("exact_accounting", accounting_drift), ("prior_raw_collision", prior_raw_collision), ("wrong_message_count", wrong_message_count), ("source_partition_drift", source_partition_drift), ("disagreement_overflow", disagreement_overflow), ("bad_disagreement_map", bad_map)])
    if supports_two_axis:
        # Classification labels remain unchanged; the independent lexical axis
        # must still reject a diagnostic exact-collision mutation.
        cases.append(("diagnostic_lexical_accounting", p12_diagnostic_lexical_drift))
    def mutation_bytes(root: pathlib.Path, mapping: pathlib.Path) -> str:
        digest = hashlib.sha256()
        for path in sorted(item for item in root.rglob("*") if item.is_file()):
            digest.update(path.relative_to(root).as_posix().encode("utf-8")); digest.update(b"\0"); digest.update(path.read_bytes())
        digest.update(b"MAP\0"); digest.update(mapping.read_bytes())
        return digest.hexdigest()
    passed = []
    with tempfile.TemporaryDirectory(prefix="tracksmith-preflight-selftest-") as temporary:
        for name, action in cases:
            root = pathlib.Path(temporary) / name; shutil.copytree(incoming, root)
            mapping = pathlib.Path(temporary) / (name + ".map.json"); shutil.copyfile(disagreement_map, mapping)
            before = mutation_bytes(root, mapping)
            action(root, mapping)
            if mutation_bytes(root, mapping) == before: fail("self-test mutation made no byte change: " + name)
            refresh_sums(root)
            try:
                validate(root, dependency_map, mapping, True, standards_map, archive)
            except PreflightError:
                passed.append(name)
            else:
                fail("self-test corruption accepted: " + name)
    if supports_two_axis:
        manifest = selftest_manifest
        data = {name: load_rows(incoming / relative) for name, relative in DATA_FILES.items()}
        runtime = trusted.stable_runtime_projection(manifest["package_id"], manifest, sha(incoming / "package_manifest.json"), data, load_json(disagreement_map))
        runtime["canonicalCards"][0]["reviewStatus"] = "must-not-ship"
        try: trusted.assert_runtime_status_free(runtime)
        except ValueError: passed.append("runtime_status_key")
        else: fail("self-test runtime status key accepted")
    spec = trusted.STABLE_CONTRACT_SPECS[selftest_manifest["package_id"]]
    if spec.get("archiveRequired") and spec.get("archiveSHA256"):
        if archive is None: fail("archive sidecar self-test requires archive")
        with tempfile.TemporaryDirectory(prefix="tracksmith-preflight-sidecar-") as temporary:
            archive_copy = pathlib.Path(temporary) / archive.name
            shutil.copyfile(archive, archive_copy)
            sidecar_copy = archive_copy.with_name(archive_copy.name + ".sha256")
            sidecar_copy.write_text("0" * 64 + "  " + archive_copy.name + "\n", encoding="utf-8")
            try:
                validate(incoming, dependency_map, disagreement_map, True, standards_map, archive_copy)
            except PreflightError as error:
                if "archive sidecar" not in str(error) or "pin drift" not in str(error): fail("archive_sidecar_pin_drift wrong guard: " + str(error))
                passed.append("archive_sidecar_pin_drift")
            else: fail("archive_sidecar_pin_drift accepted")
    if incoming.name == "tracksmith-corpus-009-gain-staging-bus-processing-loudness":
        if standards_map is None: fail("P9 self-test requires standards map")
        passed.extend(p9_specific_self_test(incoming, dependency_map, disagreement_map, standards_map, archive))
    print("CORPUS_PREFLIGHT_SELFTEST_OK cases=%d rejected=%s" % (len(passed), ",".join(passed)))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--incoming", type=pathlib.Path, default=COMMUNITY / "packages/tracksmith-corpus-005-automation")
    parser.add_argument("--dependency-map", type=pathlib.Path, default=COMMUNITY / "dependency_maps/tracksmith-corpus-005-automation.json")
    parser.add_argument("--disagreement-map", type=pathlib.Path)
    parser.add_argument("--standards-map", type=pathlib.Path)
    parser.add_argument("--archive", type=pathlib.Path)
    parser.add_argument("--strict-stage", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    arguments = parser.parse_args()
    incoming = arguments.incoming.expanduser()
    dependency = arguments.dependency_map.expanduser()
    disagreement = arguments.disagreement_map.expanduser() if arguments.disagreement_map else None
    standards = arguments.standards_map.expanduser() if arguments.standards_map else None
    archive = arguments.archive.expanduser() if arguments.archive else None
    if arguments.strict_stage and disagreement is None:
        fail("--strict-stage requires --disagreement-map")
    if arguments.self_test:
        if disagreement is None:
            fail("--self-test requires --disagreement-map")
        self_test(incoming, dependency, disagreement, standards, archive)
    else:
        pid, _ = validate(incoming, dependency, disagreement, arguments.strict_stage, standards, archive)
        print("CORPUS_PREFLIGHT_OK incoming=%s strictStage=%s writes=0" % (pid, str(arguments.strict_stage).lower()))


if __name__ == "__main__":
    try:
        main()
    except (OSError, TypeError, KeyError, sqlite3.Error, PreflightError) as error:
        print("CORPUS_PREFLIGHT_ERROR: " + str(error), file=sys.stderr)
        raise SystemExit(1)
