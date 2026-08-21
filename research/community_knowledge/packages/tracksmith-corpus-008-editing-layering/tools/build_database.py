#!/usr/bin/env python3
from __future__ import annotations

import json
import sqlite3
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DB = ROOT / "database" / "corpus.sqlite"


def read_jsonl(path: Path) -> list[dict]:
    with path.open(encoding="utf-8") as handle:
        return [json.loads(line) for line in handle if line.strip()]


def main() -> None:
    manifest = json.loads((ROOT / "package_manifest.json").read_text(encoding="utf-8"))
    if DB.exists():
        DB.unlink()
    connection = sqlite3.connect(DB)
    cursor = connection.cursor()
    cursor.executescript(
        """
        PRAGMA journal_mode=DELETE;
        PRAGMA foreign_keys=ON;
        CREATE TABLE packages(package_id TEXT PRIMARY KEY, package_number INTEGER NOT NULL, contract_version TEXT NOT NULL, package_version TEXT NOT NULL, manifest_json TEXT NOT NULL);
        CREATE TABLE canonical_qa(id TEXT PRIMARY KEY, package_id TEXT NOT NULL, domain TEXT NOT NULL, subdomain TEXT NOT NULL, topic TEXT NOT NULL, title TEXT NOT NULL, canonical_question TEXT NOT NULL, direct_answer TEXT NOT NULL, recommended_first_experiment TEXT NOT NULL, review_state TEXT NOT NULL, source_ids_json TEXT NOT NULL, record_json TEXT NOT NULL);
        CREATE TABLE user_utterances(id TEXT PRIMARY KEY, canonical_qa_id TEXT NOT NULL REFERENCES canonical_qa(id), text TEXT NOT NULL, variant_type TEXT NOT NULL, record_json TEXT NOT NULL);
        CREATE TABLE multiturn_scenarios(id TEXT PRIMARY KEY, canonical_qa_id TEXT NOT NULL REFERENCES canonical_qa(id), scenario_type TEXT NOT NULL, record_json TEXT NOT NULL);
        CREATE TABLE retrieval_evaluations(id TEXT PRIMARY KEY, canonical_qa_id TEXT NOT NULL REFERENCES canonical_qa(id), evaluation_type TEXT NOT NULL, query TEXT NOT NULL, record_json TEXT NOT NULL);
        CREATE TABLE contradictions(id TEXT PRIMARY KEY, topic TEXT NOT NULL, position_a TEXT NOT NULL, position_b TEXT NOT NULL, record_json TEXT NOT NULL);
        CREATE TABLE myths_and_antipatterns(id TEXT PRIMARY KEY, myth TEXT NOT NULL, correction TEXT NOT NULL, record_json TEXT NOT NULL);
        CREATE TABLE claim_candidates(id TEXT PRIMARY KEY, canonical_qa_id TEXT NOT NULL REFERENCES canonical_qa(id), claim_text TEXT NOT NULL, review_state TEXT NOT NULL, record_json TEXT NOT NULL);
        CREATE TABLE strategy_candidates(id TEXT PRIMARY KEY, canonical_qa_id TEXT NOT NULL REFERENCES canonical_qa(id), label TEXT NOT NULL, review_state TEXT NOT NULL, record_json TEXT NOT NULL);
        CREATE TABLE logic_procedure_candidates(id TEXT PRIMARY KEY, canonical_qa_id TEXT NOT NULL REFERENCES canonical_qa(id), title TEXT NOT NULL, verification_status TEXT NOT NULL, review_state TEXT NOT NULL, record_json TEXT NOT NULL);
        CREATE TABLE sources(id TEXT PRIMARY KEY, title TEXT NOT NULL, publisher_or_community TEXT NOT NULL, canonical_url TEXT NOT NULL, evidence_class TEXT NOT NULL, access_mode TEXT NOT NULL, record_json TEXT NOT NULL);
        CREATE TABLE provenance(id TEXT PRIMARY KEY, canonical_qa_id TEXT NOT NULL REFERENCES canonical_qa(id), source_ids_json TEXT NOT NULL, record_json TEXT NOT NULL);
        CREATE VIRTUAL TABLE canonical_qa_fts USING fts5(id UNINDEXED, title, canonical_question, direct_answer, experiment, tags, utterances, tokenize='unicode61 remove_diacritics 2');
        CREATE INDEX idx_canonical_subdomain ON canonical_qa(subdomain);
        CREATE INDEX idx_utterance_qa ON user_utterances(canonical_qa_id);
        CREATE INDEX idx_scenario_qa ON multiturn_scenarios(canonical_qa_id);
        CREATE INDEX idx_eval_qa ON retrieval_evaluations(canonical_qa_id);
        """
    )
    cursor.execute(
        "INSERT INTO packages VALUES (?,?,?,?,?)",
        (
            manifest["package_id"], manifest["package_number"], manifest["contract_version"],
            manifest["package_version"], json.dumps(manifest, sort_keys=True, ensure_ascii=False),
        ),
    )

    utterance_rows = read_jsonl(ROOT / "corpus" / "user_utterances.jsonl")
    utterances_by_qa: dict[str, list[str]] = defaultdict(list)
    for row in utterance_rows:
        utterances_by_qa[row["canonical_qa_id"]].append(row["text"])

    canonical = read_jsonl(ROOT / "corpus" / "canonical_qa.jsonl")
    for row in canonical:
        raw = json.dumps(row, sort_keys=True, ensure_ascii=False)
        cursor.execute(
            "INSERT INTO canonical_qa VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
            (
                row["id"], row["package_id"], row["domain"], row["subdomain"], row["topic"],
                row["title"], row["canonical_question"], row["direct_answer"],
                row["recommended_first_experiment"], row["review_state"],
                json.dumps(row["source_ids"]), raw,
            ),
        )
        cursor.execute(
            "INSERT INTO canonical_qa_fts VALUES (?,?,?,?,?,?,?)",
            (
                row["id"], row["title"], row["canonical_question"], row["direct_answer"],
                row["recommended_first_experiment"], " ".join(row["retrieval_tags"]),
                "\n".join(utterances_by_qa.get(row["id"], [])),
            ),
        )

    mappings = [
        ("corpus/user_utterances.jsonl", "user_utterances", lambda r: (r["id"], r["canonical_qa_id"], r["text"], r["variant_type"], json.dumps(r, sort_keys=True, ensure_ascii=False))),
        ("corpus/multiturn_scenarios.jsonl", "multiturn_scenarios", lambda r: (r["id"], r["canonical_qa_id"], r["scenario_type"], json.dumps(r, sort_keys=True, ensure_ascii=False))),
        ("corpus/retrieval_evaluations.jsonl", "retrieval_evaluations", lambda r: (r["id"], r["canonical_qa_id"], r["evaluation_type"], r["query"], json.dumps(r, sort_keys=True, ensure_ascii=False))),
        ("corpus/contradictions.jsonl", "contradictions", lambda r: (r["id"], r["topic"], r["position_a"], r["position_b"], json.dumps(r, sort_keys=True, ensure_ascii=False))),
        ("corpus/myths_and_antipatterns.jsonl", "myths_and_antipatterns", lambda r: (r["id"], r["myth"], r["correction"], json.dumps(r, sort_keys=True, ensure_ascii=False))),
        ("knowledge_candidates/claims.jsonl", "claim_candidates", lambda r: (r["id"], r["canonical_qa_id"], r["claim_text"], r["review_state"], json.dumps(r, sort_keys=True, ensure_ascii=False))),
        ("knowledge_candidates/strategies.jsonl", "strategy_candidates", lambda r: (r["id"], r["canonical_qa_id"], r["label"], r["review_state"], json.dumps(r, sort_keys=True, ensure_ascii=False))),
        ("knowledge_candidates/logic_procedures.jsonl", "logic_procedure_candidates", lambda r: (r["id"], r["canonical_qa_id"], r["title"], r["verification_status"], r["review_state"], json.dumps(r, sort_keys=True, ensure_ascii=False))),
        ("sources/source_registry.jsonl", "sources", lambda r: (r["id"], r["title"], r["publisher_or_community"], r["canonical_url"], r["evidence_class"], r["access_mode"], json.dumps(r, sort_keys=True, ensure_ascii=False))),
        ("sources/provenance_manifest.jsonl", "provenance", lambda r: (r["id"], r["canonical_qa_id"], json.dumps(r["source_ids"]), json.dumps(r, sort_keys=True, ensure_ascii=False))),
    ]
    for relative, table, row_function in mappings:
        rows = utterance_rows if relative == "corpus/user_utterances.jsonl" else read_jsonl(ROOT / relative)
        if not rows:
            continue
        placeholders = ",".join("?" for _ in row_function(rows[0]))
        for row in rows:
            cursor.execute(f"INSERT INTO {table} VALUES ({placeholders})", row_function(row))

    connection.commit()
    status = cursor.execute("PRAGMA integrity_check").fetchone()[0]
    connection.close()
    if status != "ok":
        raise SystemExit(f"Database integrity failed: {status}")
    print(f"Built {DB}")


if __name__ == "__main__":
    main()
