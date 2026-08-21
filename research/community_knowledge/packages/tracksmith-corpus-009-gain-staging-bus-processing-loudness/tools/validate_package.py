#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import sqlite3
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REQUIRED_DIRS = {
    "integration", "corpus", "knowledge_candidates", "sources", "schemas",
    "database", "tools", "tests", "reports", "examples"
}
REQUIRED_FILES = {
    "README.md", "package_manifest.json", "PACKAGE_SHA256SUMS.txt",
    "integration/START_HERE_FOR_CODEX.md", "integration/PACKAGE_SEQUENCE.md",
    "integration/TRACKSMITH_IMPORT_PLAN.md", "integration/REVIEW_CHECKLIST.md",
    "integration/TOOL_CONTRACT.md",
    "corpus/canonical_qa.jsonl", "corpus/user_utterances.jsonl",
    "corpus/multiturn_scenarios.jsonl", "corpus/retrieval_evaluations.jsonl",
    "corpus/contradictions.jsonl", "corpus/myths_and_antipatterns.jsonl",
    "knowledge_candidates/claims.jsonl", "knowledge_candidates/strategies.jsonl",
    "knowledge_candidates/logic_procedures.jsonl",
    "sources/source_registry.jsonl", "sources/source_access_manifest.json",
    "sources/provenance_manifest.jsonl",
    "database/corpus.sqlite", "database/database_manifest.json",
    "tools/build_database.py", "tools/validate_package.py", "tools/query_corpus.py",
    "tools/inspect_package.py", "tools/import_to_tracksmith.py",
    "tests/retrieval_cases.jsonl", "tests/integrity_cases.jsonl",
    "tests/expected_statistics.json",
    "reports/COVERAGE_REPORT.md", "reports/SOURCE_REPORT.md",
    "reports/QUALITY_BOUNDARIES.md", "reports/VALIDATION_REPORT.md",
    "examples/example_canonical_record.json", "examples/example_multiturn_scenario.json",
    "examples/example_queries.md",
}
SCHEMAS = {
    "canonical_qa": ("schemas/canonical_qa.schema.json", "corpus/canonical_qa.jsonl"),
    "user_utterances": ("schemas/user_utterance.schema.json", "corpus/user_utterances.jsonl"),
    "multiturn_scenarios": ("schemas/multiturn_scenario.schema.json", "corpus/multiturn_scenarios.jsonl"),
    "retrieval_evaluations": ("schemas/retrieval_evaluation.schema.json", "corpus/retrieval_evaluations.jsonl"),
    "contradictions": ("schemas/contradiction.schema.json", "corpus/contradictions.jsonl"),
    "myths_and_antipatterns": ("schemas/myth.schema.json", "corpus/myths_and_antipatterns.jsonl"),
    "claim_candidates": ("schemas/claim_candidate.schema.json", "knowledge_candidates/claims.jsonl"),
    "strategy_candidates": ("schemas/strategy_candidate.schema.json", "knowledge_candidates/strategies.jsonl"),
    "logic_procedure_candidates": ("schemas/logic_procedure_candidate.schema.json", "knowledge_candidates/logic_procedures.jsonl"),
}


def jsonl(relative: str) -> list[dict]:
    with (ROOT / relative).open(encoding="utf-8") as handle:
        return [json.loads(line) for line in handle if line.strip()]


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def fail(message: str) -> None:
    print("FAIL:", message, file=sys.stderr)
    raise SystemExit(1)


def validate_required_fields(name: str, rows: list[dict], schema_path: str) -> None:
    schema = json.loads((ROOT / schema_path).read_text(encoding="utf-8"))
    required = schema.get("required", [])
    for row in rows:
        missing = [key for key in required if key not in row]
        if missing:
            fail(f"{name} {row.get('id', '<unknown>')} missing required fields: {missing}")


def main() -> None:
    for directory in REQUIRED_DIRS:
        if not (ROOT / directory).is_dir():
            fail(f"missing directory {directory}")
    for file_name in REQUIRED_FILES:
        if not (ROOT / file_name).is_file():
            fail(f"missing file {file_name}")

    manifest = json.loads((ROOT / "package_manifest.json").read_text(encoding="utf-8"))
    if manifest.get("package_contract") != "tracksmith-corpus-package" or manifest.get("contract_version") != "1.0":
        fail("package contract mismatch")
    if manifest.get("id_namespace") != "pkg009" or manifest.get("package_number") != 9:
        fail("package namespace/number mismatch")
    if len(set(manifest.get("depends_on", []))) != len(manifest.get("depends_on", [])):
        fail("duplicate package dependency")

    files = {
        "canonical_qa": jsonl("corpus/canonical_qa.jsonl"),
        "user_utterances": jsonl("corpus/user_utterances.jsonl"),
        "multiturn_scenarios": jsonl("corpus/multiturn_scenarios.jsonl"),
        "retrieval_evaluations": jsonl("corpus/retrieval_evaluations.jsonl"),
        "contradictions": jsonl("corpus/contradictions.jsonl"),
        "myths_and_antipatterns": jsonl("corpus/myths_and_antipatterns.jsonl"),
        "claim_candidates": jsonl("knowledge_candidates/claims.jsonl"),
        "strategy_candidates": jsonl("knowledge_candidates/strategies.jsonl"),
        "logic_procedure_candidates": jsonl("knowledge_candidates/logic_procedures.jsonl"),
        "sources": jsonl("sources/source_registry.jsonl"),
        "provenance": jsonl("sources/provenance_manifest.jsonl"),
    }

    all_ids: set[str] = set()
    for name, rows in files.items():
        expected = manifest["record_counts"][name]
        if len(rows) != expected:
            fail(f"{name}: {len(rows)} != {expected}")
        ids = [row["id"] for row in rows]
        if len(ids) != len(set(ids)):
            fail(f"duplicate IDs in {name}")
        if any(not identifier.startswith("pkg009.") for identifier in ids):
            fail(f"ID outside pkg009 namespace in {name}")
        collision = all_ids.intersection(ids)
        if collision:
            fail(f"cross-file ID collision: {sorted(collision)[:5]}")
        all_ids.update(ids)

    for name, (schema_path, _) in SCHEMAS.items():
        validate_required_fields(name, files[name], schema_path)

    domain_counts = Counter(row["domain"] for row in files["canonical_qa"])
    if domain_counts != Counter({"gain_staging": 140, "bus_processing": 130, "clipping_limiting_loudness": 160}):
        fail(f"canonical domain counts mismatch: {dict(domain_counts)}")
    subdomain_counts = Counter(row["subdomain"] for row in files["canonical_qa"])
    if dict(sorted(subdomain_counts.items())) != dict(sorted(manifest.get("canonical_subdomain_counts", {}).items())):
        fail(f"canonical subdomain counts mismatch: {dict(subdomain_counts)}")
    canonical_ids = {row["id"] for row in files["canonical_qa"]}
    source_ids = {row["id"] for row in files["sources"]}
    canonical_questions = [row["canonical_question"].strip().casefold() for row in files["canonical_qa"]]
    if len(canonical_questions) != len(set(canonical_questions)):
        fail("duplicate canonical questions")
    utterance_texts = [row["text"].strip().casefold() for row in files["user_utterances"]]
    if len(utterance_texts) != len(set(utterance_texts)):
        fail("duplicate user utterance text")

    linked_files = (
        "user_utterances", "multiturn_scenarios", "retrieval_evaluations",
        "claim_candidates", "strategy_candidates", "logic_procedure_candidates", "provenance"
    )
    for name in linked_files:
        for row in files[name]:
            if row["canonical_qa_id"] not in canonical_ids:
                fail(f"{name} bad canonical link {row['id']}")

    for row in files["canonical_qa"]:
        if row["review_state"] != "candidate_not_yet_human_reviewed":
            fail(f"bad review state {row['id']}")
        if row["logic_guidance"]["verification_status"] != "candidate_unverified_on_installed_logic":
            fail(f"bad Logic status {row['id']}")
        unknown = set(row["source_ids"]) - source_ids
        if unknown:
            fail(f"unknown sources {row['id']}: {sorted(unknown)}")

    for name in ("claim_candidates", "strategy_candidates", "logic_procedure_candidates", "provenance"):
        for row in files[name]:
            unknown = set(row.get("source_ids", [])) - source_ids
            if unknown:
                fail(f"unknown candidate/provenance sources {row['id']}: {sorted(unknown)}")

    for name in ("contradictions", "myths_and_antipatterns"):
        for row in files[name]:
            unknown = set(row.get("source_ids", [])) - source_ids
            if unknown:
                fail(f"unknown {name} sources {row['id']}: {sorted(unknown)}")

    for row in files["logic_procedure_candidates"]:
        if row["execution_authority"] is not False:
            fail(f"procedure has execution authority {row['id']}")
        if row["verification_status"] != "candidate_unverified_on_installed_logic":
            fail(f"procedure verification state changed {row['id']}")

    source_urls = [row["canonical_url"] for row in files["sources"]]
    if len(source_urls) != len(set(source_urls)):
        fail("duplicate canonical source URL")

    access = json.loads((ROOT / "sources/source_access_manifest.json").read_text(encoding="utf-8"))
    if access.get("reddit_status") != "MANUAL_PUBLIC_SEEDS_ONLY":
        fail("unexpected Reddit access status")
    if manifest["source_policy"].get("raw_forum_text_included") or manifest["source_policy"].get("long_verbatim_source_text_included"):
        fail("raw or long-verbatim forum text unexpectedly included")

    expected = json.loads((ROOT / "tests/expected_statistics.json").read_text(encoding="utf-8"))
    if expected.get("record_counts") != manifest.get("record_counts"):
        fail("expected statistics do not match manifest counts")

    connection = sqlite3.connect(ROOT / "database/corpus.sqlite")
    status = connection.execute("PRAGMA integrity_check").fetchone()[0]
    if status != "ok":
        fail("database integrity: " + status)
    table_mapping = [
        ("canonical_qa", "canonical_qa"), ("user_utterances", "user_utterances"),
        ("multiturn_scenarios", "multiturn_scenarios"),
        ("retrieval_evaluations", "retrieval_evaluations"),
        ("contradictions", "contradictions"),
        ("myths_and_antipatterns", "myths_and_antipatterns"),
        ("claim_candidates", "claim_candidates"),
        ("strategy_candidates", "strategy_candidates"),
        ("logic_procedure_candidates", "logic_procedure_candidates"),
        ("sources", "sources"), ("provenance", "provenance"),
    ]
    for table, key in table_mapping:
        count = connection.execute(f"SELECT count(*) FROM {table}").fetchone()[0]
        if count != len(files[key]):
            fail(f"database table {table}: {count} != {len(files[key])}")
    package_row = connection.execute("SELECT package_id, contract_version FROM packages").fetchone()
    if package_row != (manifest["package_id"], manifest["contract_version"]):
        fail("database package metadata mismatch")
    for query in ("analog modeled headroom", "pre fader metering", "region gain fader", "drum bus compression", "VCA aux subgroup", "parallel bus louder", "peak RMS LUFS", "true peak limiter ceiling", "clipper before limiter", "streaming loudness normalization"):
        count = connection.execute(
            "SELECT count(*) FROM canonical_qa_fts WHERE canonical_qa_fts MATCH ?", (query,)
        ).fetchone()[0]
        if count < 1:
            fail(f"FTS query returned no result: {query}")
    connection.close()

    checksum_path = ROOT / "PACKAGE_SHA256SUMS.txt"
    checksum_lines = [line.strip() for line in checksum_path.read_text(encoding="utf-8").splitlines() if line.strip()]
    if any(line.endswith("  PACKAGE_SHA256SUMS.txt") for line in checksum_lines):
        fail("checksum manifest must not include itself")
    checked: set[str] = set()
    for line in checksum_lines:
        try:
            expected_sha, relative = line.split("  ", 1)
        except ValueError:
            fail(f"malformed checksum line: {line}")
        path = ROOT / relative
        if not path.is_file():
            fail(f"checksum references missing file {relative}")
        if relative in checked:
            fail(f"duplicate checksum entry {relative}")
        checked.add(relative)
        if sha256(path) != expected_sha:
            fail(f"checksum mismatch {relative}")
    expected_checksum_files = {
        str(path.relative_to(ROOT))
        for path in ROOT.rglob("*")
        if path.is_file() and path.name != "PACKAGE_SHA256SUMS.txt" and "__pycache__" not in path.parts
    }
    if checked != expected_checksum_files:
        missing = sorted(expected_checksum_files - checked)
        extra = sorted(checked - expected_checksum_files)
        fail(f"checksum coverage mismatch; missing={missing[:5]} extra={extra[:5]}")

    print("PASS")
    print(json.dumps({
        "package_id": manifest["package_id"],
        "canonical_qa": len(files["canonical_qa"]),
        "user_utterances": len(files["user_utterances"]),
        "unique_user_utterances": len(set(utterance_texts)),
        "multiturn_scenarios": len(files["multiturn_scenarios"]),
        "retrieval_evaluations": len(files["retrieval_evaluations"]),
        "sources": len(files["sources"]),
        "contradictions": len(files["contradictions"]),
        "myths": len(files["myths_and_antipatterns"]),
        "database_integrity": "ok",
        "reddit_status": access["reddit_status"],
    }, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
