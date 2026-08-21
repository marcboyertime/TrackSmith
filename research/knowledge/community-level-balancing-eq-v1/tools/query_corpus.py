#!/usr/bin/env python3
import argparse, json, sqlite3
from pathlib import Path
p=argparse.ArgumentParser(); p.add_argument('query'); p.add_argument('--db',default=str(Path(__file__).parents[1]/'database/tracksmith_level_eq_knowledge.sqlite3')); p.add_argument('--limit',type=int,default=10); p.add_argument('--domain',choices=['level_balancing','equalization']); a=p.parse_args()
con=sqlite3.connect(a.db); con.row_factory=sqlite3.Row
tokens=[t for t in __import__('re').findall(r'[A-Za-z0-9]+',a.query.lower()) if len(t)>1]
match=' OR '.join('"'+t.replace('"','')+'"' for t in tokens) if tokens else a.query
q='SELECT u.canonical_id, u.text, bm25(utterance_fts) score FROM utterance_fts u WHERE utterance_fts MATCH ?'
params=[match]
if a.domain: q+=' AND domain=?'; params.append(a.domain)
q+=' ORDER BY score LIMIT ?'; params.append(a.limit)
rows=con.execute(q,params).fetchall(); out=[]
for row in rows:
 c=con.execute('SELECT json FROM canonical WHERE id=?',(row['canonical_id'],)).fetchone()
 if c: out.append({'matched_utterance':row['text'],'score':row['score'],'canonical':json.loads(c['json'])})
print(json.dumps(out,indent=2,ensure_ascii=False))
