#!/usr/bin/env python3
"""Query the Package 4 canonical and utterance FTS indexes."""

from __future__ import annotations
import argparse, json, re, sqlite3
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
DB=ROOT/"database"/"tracksmith_reverb_delay_knowledge.sqlite3"

def fts_query(text: str) -> str:
    tokens=re.findall(r"[A-Za-z0-9]+", text.lower())
    tokens=[t for t in tokens if len(t)>1]
    return " OR ".join(f'"{t}"' for t in tokens[:16])

def main():
    p=argparse.ArgumentParser()
    p.add_argument("query")
    p.add_argument("--domain",choices=["reverb","delay"])
    p.add_argument("--limit",type=int,default=10)
    args=p.parse_args()
    expr=fts_query(args.query)
    if not expr:
        raise SystemExit("No searchable terms.")
    con=sqlite3.connect(DB)
    con.row_factory=sqlite3.Row
    sql="""SELECT c.id,c.domain,c.category,c.title,c.question,c.first_experiment,
                  bm25(canonical_fts) AS score
           FROM canonical_fts JOIN canonical c ON c.id=canonical_fts.id
           WHERE canonical_fts MATCH ?"""
    vals=[expr]
    if args.domain:
        sql+=" AND c.domain=?"
        vals.append(args.domain)
    sql+=" ORDER BY score LIMIT ?"
    vals.append(max(1,min(args.limit,50)))
    rows=[dict(r) for r in con.execute(sql,vals)]
    print(json.dumps({"query":args.query,"fts":expr,"results":rows},indent=2,ensure_ascii=False))
    con.close()

if __name__=="__main__":
    main()
