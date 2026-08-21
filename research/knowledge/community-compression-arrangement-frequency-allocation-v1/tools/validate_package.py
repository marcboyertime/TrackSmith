#!/usr/bin/env python3
from __future__ import annotations
import hashlib, json, sqlite3
from collections import Counter
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def load(rel):
 rows=[]
 with (ROOT/rel).open(encoding='utf-8') as f:
  for n,line in enumerate(f,1):
   line=line.strip()
   if line:
    try: rows.append(json.loads(line))
    except Exception as e: raise AssertionError(f'{rel}:{n}: {e}')
 return rows
def ids(rows,key,label):
 vals=[r[key] for r in rows]; assert len(vals)==len(set(vals)),f'duplicate {label} IDs'; return set(vals)
canonical=load('corpus/canonical_qa.jsonl'); comp=load('corpus/compression_canonical.jsonl'); arr=load('corpus/arrangement_canonical.jsonl'); freq=load('corpus/frequency_allocation_canonical.jsonl')
utter=load('corpus/user_utterances.jsonl'); scenarios=load('corpus/multiturn_scenarios.jsonl'); evals=load('corpus/evaluation_cases.jsonl'); sources=load('research/source_registry.jsonl'); contradictions=load('research/contradictions.jsonl'); myths=load('research/myths_and_antipatterns.jsonl'); claims=load('integration/tracksmith_claim_candidates.jsonl'); strategies=load('integration/tracksmith_strategy_candidates.jsonl'); procedures=load('integration/logic_procedure_candidates.jsonl')
assert len(canonical)==350,len(canonical); assert len(comp)==130; assert len(arr)==110; assert len(freq)==110
assert len(utter)>=7000,len(utter); assert len(scenarios)==1050; assert len(evals)==1750; assert len(sources)>=85,len(sources); assert len(contradictions)>=30; assert len(myths)>=45; assert len(claims)==len(strategies)==len(procedures)==350
cids=ids(canonical,'id','canonical'); assert ids(comp,'id','compression')|ids(arr,'id','arrangement')|ids(freq,'id','frequency')==cids
sids=ids(sources,'source_id','source'); ids(utter,'utterance_id','utterance'); ids(scenarios,'scenario_id','scenario'); ids(evals,'evaluation_id','evaluation')
assert Counter(r['domain'] for r in canonical)=={'compression':130,'arrangement':110,'frequency_allocation':110}
for r in canonical:
 assert r['package_sequence']==3; assert r['review_status']=='candidate_not_yet_human_reviewed'; assert r['source_ids'] and set(r['source_ids'])<=sids,r['id']; assert len(r['candidate_hypotheses'])>=4; assert len(r['logic_pro_steps'])>=4; assert r['numeric_guidance_policy']=='starting_point_not_preset'
for r in utter+scenarios+evals: assert r['canonical_id'] in cids
for collection in (claims,strategies,procedures):
 for r in collection: assert r['canonical_id'] in cids; assert r['review_status']=='candidate_not_yet_human_reviewed'
conn=sqlite3.connect(ROOT/'corpus/tracksmith_compression_arrangement_frequency_knowledge.sqlite3'); assert conn.execute('pragma integrity_check').fetchone()[0]=='ok'; assert conn.execute('select count(*) from canonical').fetchone()[0]==350; assert conn.execute('select count(*) from utterances').fetchone()[0]==len(utter)
checks=[('vocal compression sibilance','compression'),('chorus smaller verse','arrangement'),('kick bass frequency conflict','frequency_allocation')]
for query,domain in checks:
 terms=' OR '.join(query.split()); rows=conn.execute('select id from canonical_fts where canonical_fts match ? and domain=? limit 40',(terms,domain)).fetchall(); assert rows,(query,domain)
conn.close()
manifest=json.loads((ROOT/'manifest.json').read_text()); assert manifest['package_sequence']==3; assert manifest['integrate_after']=='TrackSmith_Level_Balancing_EQ_QA_Corpus_v1'
for rel,digest in manifest['files'].items():
 p=ROOT/rel; assert p.exists(),rel; got=hashlib.sha256(p.read_bytes()).hexdigest(); assert got==digest,(rel,got,digest)
print('PASS'); print('Canonical:',len(canonical),'compression',len(comp),'arrangement',len(arr),'frequency',len(freq)); print('Utterances:',len(utter)); print('Scenarios:',len(scenarios)); print('Evaluations:',len(evals)); print('Sources:',len(sources)); print('Contradictions:',len(contradictions),'Myths:',len(myths)); print('SQLite FTS5: OK')
