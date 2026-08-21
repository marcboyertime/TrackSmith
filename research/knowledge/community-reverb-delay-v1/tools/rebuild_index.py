#!/usr/bin/env python3
"""Rebuild the Package 4 SQLite FTS5 index from immutable JSONL sources."""

from __future__ import annotations
import json, sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DB = ROOT / "database" / "tracksmith_reverb_delay_knowledge.sqlite3"

def read_jsonl(path: Path):
    with path.open(encoding="utf-8") as f:
        for line in f:
            line=line.strip()
            if line:
                yield json.loads(line)

def main():
    canonical=list(read_jsonl(ROOT/"corpus/canonical_qa.jsonl"))
    utterances=list(read_jsonl(ROOT/"corpus/user_utterances.jsonl"))
    sources=list(read_jsonl(ROOT/"research/source_registry.jsonl"))
    contradictions=list(read_jsonl(ROOT/"research/contradictions.jsonl"))
    myths=list(read_jsonl(ROOT/"research/myths_and_antipatterns.jsonl"))
    scenarios=list(read_jsonl(ROOT/"corpus/multiturn_scenarios.jsonl"))
    evaluations=list(read_jsonl(ROOT/"corpus/retrieval_evaluation.jsonl"))

    if DB.exists():
        DB.unlink()
    con=sqlite3.connect(DB)
    cur=con.cursor()
    cur.executescript("""
    PRAGMA journal_mode=WAL;
    PRAGMA foreign_keys=ON;
    CREATE TABLE canonical (
     id TEXT PRIMARY KEY, domain TEXT NOT NULL, category TEXT NOT NULL,
     title TEXT NOT NULL, question TEXT NOT NULL, aliases_json TEXT NOT NULL,
     mechanism TEXT NOT NULL, first_experiment TEXT NOT NULL,
     tags_json TEXT NOT NULL, source_ids_json TEXT NOT NULL,
     review_status TEXT NOT NULL, payload_json TEXT NOT NULL
    );
    CREATE TABLE utterances (
     id TEXT PRIMARY KEY, canonical_id TEXT NOT NULL REFERENCES canonical(id),
     domain TEXT NOT NULL, variant_type TEXT NOT NULL, text TEXT NOT NULL,
     payload_json TEXT NOT NULL
    );
    CREATE TABLE sources (
     source_id TEXT PRIMARY KEY, title TEXT NOT NULL, publisher TEXT NOT NULL,
     url TEXT NOT NULL, source_type TEXT NOT NULL, evidence_tier TEXT NOT NULL,
     payload_json TEXT NOT NULL
    );
    CREATE TABLE contradictions (
     id TEXT PRIMARY KEY, domain TEXT NOT NULL, topic TEXT NOT NULL,
     payload_json TEXT NOT NULL
    );
    CREATE TABLE myths (
     id TEXT PRIMARY KEY, domain TEXT NOT NULL, myth TEXT NOT NULL,
     payload_json TEXT NOT NULL
    );
    CREATE TABLE scenarios (
     id TEXT PRIMARY KEY, canonical_id TEXT NOT NULL REFERENCES canonical(id),
     domain TEXT NOT NULL, scenario_type TEXT NOT NULL, payload_json TEXT NOT NULL
    );
    CREATE TABLE evaluations (
     id TEXT PRIMARY KEY, query TEXT NOT NULL, expected_domain TEXT NOT NULL,
     expected_ids_json TEXT NOT NULL, payload_json TEXT NOT NULL
    );
    CREATE VIRTUAL TABLE canonical_fts USING fts5(
     id UNINDEXED, domain UNINDEXED, category UNINDEXED,
     title, question, aliases, mechanism, first_experiment, tags,
     tokenize='porter unicode61'
    );
    CREATE VIRTUAL TABLE utterances_fts USING fts5(
     id UNINDEXED, canonical_id UNINDEXED, domain UNINDEXED, text,
     tokenize='porter unicode61'
    );
    """)
    for c in canonical:
        aliases=" ".join(c.get("natural_language_variants",[])+c.get("user_language_aliases",[]))
        mech=c["candidate_hypotheses"][0]["mechanism"]
        payload=json.dumps(c,ensure_ascii=False,sort_keys=True)
        cur.execute("INSERT INTO canonical VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",(
            c["id"],c["domain"],c["category"],c["title"],c["canonical_user_question"],
            json.dumps(c.get("user_language_aliases",[]),ensure_ascii=False),
            mech,c["recommended_first_experiment"]["action"],
            json.dumps(c.get("tags",[]),ensure_ascii=False),
            json.dumps(c.get("source_ids",[]),ensure_ascii=False),
            c["review_status"],payload))
        cur.execute("INSERT INTO canonical_fts VALUES (?,?,?,?,?,?,?,?,?)",(
            c["id"],c["domain"],c["category"],c["title"],c["canonical_user_question"],
            aliases,mech,c["recommended_first_experiment"]["action"]," ".join(c.get("tags",[]))))
    for u in utterances:
        p=json.dumps(u,ensure_ascii=False,sort_keys=True)
        cur.execute("INSERT INTO utterances VALUES (?,?,?,?,?,?)",(
            u["id"],u["canonical_id"],u["domain"],u["variant_type"],u["text"],p))
        cur.execute("INSERT INTO utterances_fts VALUES (?,?,?,?)",(
            u["id"],u["canonical_id"],u["domain"],u["text"]))
    for s in sources:
        cur.execute("INSERT INTO sources VALUES (?,?,?,?,?,?,?)",(
            s["source_id"],s["title"],s["publisher"],s["url"],s["source_type"],
            s["evidence_tier"],json.dumps(s,ensure_ascii=False,sort_keys=True)))
    for r in contradictions:
        cur.execute("INSERT INTO contradictions VALUES (?,?,?,?)",(
            r["id"],r["domain"],r["topic"],json.dumps(r,ensure_ascii=False,sort_keys=True)))
    for m in myths:
        cur.execute("INSERT INTO myths VALUES (?,?,?,?)",(
            m["id"],m["domain"],m["myth"],json.dumps(m,ensure_ascii=False,sort_keys=True)))
    for s in scenarios:
        cur.execute("INSERT INTO scenarios VALUES (?,?,?,?,?)",(
            s["id"],s["canonical_id"],s["domain"],s["scenario_type"],
            json.dumps(s,ensure_ascii=False,sort_keys=True)))
    for e in evaluations:
        cur.execute("INSERT INTO evaluations VALUES (?,?,?,?,?)",(
            e["id"],e["query"],e["expected_domain"],
            json.dumps(e["expected_canonical_ids"]),
            json.dumps(e,ensure_ascii=False,sort_keys=True)))
    con.commit()
    integrity=cur.execute("PRAGMA integrity_check").fetchone()[0]
    print(f"Rebuilt {DB}")
    print(f"Canonical={len(canonical)} Utterances={len(utterances)} Integrity={integrity}")
    con.close()

if __name__=="__main__":
    main()
