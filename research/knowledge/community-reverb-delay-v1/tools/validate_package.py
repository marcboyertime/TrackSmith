#!/usr/bin/env python3
"""Validate TrackSmith Reverb + Delay Q&A Corpus Package 4 using stdlib only."""

from __future__ import annotations
import hashlib, json, re, sqlite3, sys
from collections import Counter
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]

def read_jsonl(rel):
    path=ROOT/rel
    out=[]
    with path.open(encoding="utf-8") as f:
        for n,line in enumerate(f,1):
            line=line.strip()
            if not line: continue
            try: out.append(json.loads(line))
            except Exception as e: raise AssertionError(f"{rel}:{n}: {e}")
    return out

def unique(records,label,key="id"):
    vals=[r[key] for r in records]
    assert len(vals)==len(set(vals)),f"duplicate {label} {key}"

def fts(text):
    toks=re.findall(r"[A-Za-z0-9]+",text.lower())
    return " OR ".join(f'"{x}"' for x in toks if len(x)>1)

def main():
    canonical=read_jsonl("corpus/canonical_qa.jsonl")
    utterances=read_jsonl("corpus/user_utterances.jsonl")
    scenarios=read_jsonl("corpus/multiturn_scenarios.jsonl")
    evaluations=read_jsonl("corpus/retrieval_evaluation.jsonl")
    sources=read_jsonl("research/source_registry.jsonl")
    contradictions=read_jsonl("research/contradictions.jsonl")
    myths=read_jsonl("research/myths_and_antipatterns.jsonl")
    claims=read_jsonl("integration/tracksmith_claim_candidates.jsonl")
    strategies=read_jsonl("integration/tracksmith_strategy_candidates.jsonl")
    procedures=read_jsonl("integration/logic_procedure_candidates.jsonl")

    assert len(canonical)==300
    assert Counter(x["domain"] for x in canonical)=={"reverb":160,"delay":140}
    assert len(utterances)==6600
    assert len(scenarios)==900
    assert len(evaluations)==1500
    assert len(sources)>=100
    assert len(contradictions)==40
    assert len(myths)==50
    assert len(claims)==len(strategies)==len(procedures)==300

    for recs,label in [(canonical,"canonical"),(utterances,"utterance"),(scenarios,"scenario"),
                       (evaluations,"evaluation"),(contradictions,"contradiction"),(myths,"myth"),
                       (claims,"claim"),(strategies,"strategy"),(procedures,"procedure")]:
        unique(recs,label)
    unique(sources,"source","source_id")

    cids={x["id"] for x in canonical}
    sids={x["source_id"] for x in sources}
    for c in canonical:
        assert c["package_sequence"]==4
        assert c["review_status"]=="candidate_not_yet_human_reviewed"
        assert c["source_ids"] and set(c["source_ids"])<=sids
        assert c["logic_pro_steps"] and c["what_to_listen_for"] and c["undo"]
    for u in utterances:
        assert u["canonical_id"] in cids and u["package_sequence"]==4
    for s in scenarios:
        assert s["canonical_id"] in cids and s["package_sequence"]==4
    for e in evaluations:
        assert set(e["expected_canonical_ids"])<=cids and e["package_sequence"]==4
    for r in contradictions:
        assert set(r["source_ids"])<=sids
    for m in myths:
        assert set(m["source_ids"])<=sids
    for p in procedures:
        assert p["review_status"]=="candidate_not_yet_human_reviewed"
        assert p["verification_status"]=="candidate_unverified_on_installed_logic"
        assert p["execution_authority"] is False

    db=ROOT/"database"/"tracksmith_reverb_delay_knowledge.sqlite3"
    con=sqlite3.connect(db)
    assert con.execute("PRAGMA integrity_check").fetchone()[0]=="ok"
    assert con.execute("SELECT count(*) FROM canonical").fetchone()[0]==300
    assert con.execute("SELECT count(*) FROM utterances").fetchone()[0]==6600
    tests=[
      ("muddy vocal reverb","reverb"),
      ("pre delay clarity","reverb"),
      ("vocal delay throw","delay"),
      ("sample delay phase","delay"),
      ("ping pong mono","delay"),
      ("Space Designer impulse","reverb"),
    ]
    for q,domain in tests:
        row=con.execute("""SELECT c.domain FROM canonical_fts
                           JOIN canonical c ON c.id=canonical_fts.id
                           WHERE canonical_fts MATCH ?
                           ORDER BY bm25(canonical_fts) LIMIT 1""",(fts(q),)).fetchone()
        assert row and row[0]==domain,(q,row)
    con.close()

    sums=ROOT/"SHA256SUMS.txt"
    if sums.exists():
        for line in sums.read_text(encoding="utf-8").splitlines():
            if not line.strip(): continue
            digest,rel=line.split("  ",1)
            data=(ROOT/rel).read_bytes()
            got=hashlib.sha256(data).hexdigest()
            assert got==digest,f"checksum mismatch: {rel}"

    print("PASS")
    print(f"Canonical: {len(canonical)} (reverb 160, delay 140)")
    print(f"Utterances: {len(utterances)}")
    print(f"Scenarios: {len(scenarios)}")
    print(f"Evaluations: {len(evaluations)}")
    print(f"Sources: {len(sources)}")
    print(f"Contradictions: {len(contradictions)}")
    print(f"Myths: {len(myths)}")
    print("SQLite FTS5: OK")

if __name__=="__main__":
    try:
        main()
    except AssertionError as e:
        print(f"FAIL: {e}",file=sys.stderr)
        raise SystemExit(1)
