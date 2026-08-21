#!/usr/bin/env python3
from __future__ import annotations
import argparse, sqlite3
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description='Query TrackSmith Package 3 FTS5 corpus')
p.add_argument('query')
p.add_argument('--domain',choices=['compression','arrangement','frequency_allocation'])
p.add_argument('--limit',type=int,default=8)
a=p.parse_args()
terms=' OR '.join(t for t in a.query.replace('"',' ').split() if t)
if not terms: raise SystemExit('query contained no terms')
conn=sqlite3.connect(ROOT/'corpus/tracksmith_compression_arrangement_frequency_knowledge.sqlite3')
sql='''SELECT c.id,c.domain,c.question,c.body,bm25(canonical_fts) score
       FROM canonical_fts JOIN canonical c ON c.id=canonical_fts.id
       WHERE canonical_fts MATCH ?'''
params=[terms]
if a.domain: sql+=' AND c.domain=?'; params.append(a.domain)
sql+=' ORDER BY score LIMIT ?'; params.append(max(1,min(a.limit,50)))
rows=conn.execute(sql,params).fetchall()
if not rows:
    sql='''SELECT DISTINCT c.id,c.domain,c.question,c.body,bm25(utterances_fts) score
           FROM utterances_fts JOIN canonical c ON c.id=utterances_fts.canonical_id
           WHERE utterances_fts MATCH ?'''
    params=[terms]
    if a.domain: sql+=' AND c.domain=?'; params.append(a.domain)
    sql+=' ORDER BY score LIMIT ?'; params.append(max(1,min(a.limit,50)))
    rows=conn.execute(sql,params).fetchall()
for rid,domain,q,body,score in rows:
    print(f'\n[{rid}] ({domain}) {q}\nscore={score:.3f}')
    print(body.split('\n')[0][:500])
conn.close()
