#!/usr/bin/env python3
from __future__ import annotations
import json, sqlite3
from collections import defaultdict
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def rows(rel):
 p=ROOT/rel
 with p.open(encoding='utf-8') as f:return [json.loads(x) for x in f if x.strip()]
def norm(s):
 import re,unicodedata
 s=unicodedata.normalize('NFKC',s).casefold().replace('’',"'")
 return ' '.join(re.sub(r'[^a-z0-9]+',' ',s).split())
def main():
 can=rows('corpus/canonical_qa.jsonl'); utt=rows('corpus/user_utterances.jsonl'); sc=rows('corpus/multiturn_scenarios.jsonl'); ev=rows('corpus/retrieval_evaluations.jsonl'); contr=rows('corpus/contradictions.jsonl'); myths=rows('corpus/myths_and_antipatterns.jsonl'); claims=rows('knowledge_candidates/claims.jsonl'); strategies=rows('knowledge_candidates/strategies.jsonl'); proc=rows('knowledge_candidates/logic_procedures.jsonl'); sources=rows('sources/source_registry.jsonl'); prov=rows('sources/provenance_manifest.jsonl')
 db=ROOT/'database/corpus.sqlite'
 if db.exists():db.unlink()
 con=sqlite3.connect(db);c=con.cursor();c.executescript("""
 CREATE TABLE canonical_qa(id TEXT PRIMARY KEY,package_id TEXT,domain TEXT,subdomain TEXT,title TEXT,canonical_question TEXT,direct_answer TEXT,diagnosis_key TEXT,experiment_key TEXT,runtime_eligibility TEXT,json TEXT);
 CREATE TABLE user_utterances(id TEXT PRIMARY KEY,canonical_qa_id TEXT,text TEXT,utterance_kind TEXT,runtime_eligibility TEXT,json TEXT);
 CREATE TABLE multiturn_scenarios(id TEXT PRIMARY KEY,canonical_qa_id TEXT,experience_level TEXT,scenario_type TEXT,diagnosis_key TEXT,experiment_key TEXT,runtime_eligibility TEXT,json TEXT);
 CREATE TABLE retrieval_evaluations(id TEXT PRIMARY KEY,canonical_qa_id TEXT,evaluation_type TEXT,query TEXT,expected_top_1 INTEGER,runtime_eligibility TEXT,json TEXT);
 CREATE TABLE contradictions(id TEXT PRIMARY KEY,topic TEXT,runtime_eligibility TEXT,json TEXT);
 CREATE TABLE myths_and_antipatterns(id TEXT PRIMARY KEY,myth TEXT,runtime_eligibility TEXT,json TEXT);
 CREATE TABLE claim_candidates(id TEXT PRIMARY KEY,canonical_qa_id TEXT,runtime_eligibility TEXT,json TEXT);
 CREATE TABLE strategy_candidates(id TEXT PRIMARY KEY,canonical_qa_id TEXT,runtime_eligibility TEXT,json TEXT);
 CREATE TABLE logic_procedure_candidates(id TEXT PRIMARY KEY,runtime_eligibility TEXT,json TEXT);
 CREATE TABLE sources(id TEXT PRIMARY KEY,title TEXT,source_type TEXT,runtime_eligibility TEXT,json TEXT);
 CREATE TABLE provenance(id TEXT PRIMARY KEY,record_id TEXT,runtime_eligibility TEXT,json TEXT);
 CREATE VIRTUAL TABLE canonical_qa_fts USING fts5(id UNINDEXED,title,canonical_question,direct_answer,utterances,tokenize='unicode61');
 CREATE TABLE exact_aliases(normalized_alias TEXT PRIMARY KEY,canonical_qa_id TEXT NOT NULL);
 """)
 for r in can:c.execute('INSERT INTO canonical_qa VALUES(?,?,?,?,?,?,?,?,?,?,?)',(r['id'],r['package_id'],r['domain'],r['subdomain'],r['title'],r['canonical_question'],r['direct_answer'],r['diagnosis_key'],r['experiment_key'],r['runtime_eligibility'],json.dumps(r,sort_keys=True,ensure_ascii=False)))
 by=defaultdict(list)
 for r in utt:
  c.execute('INSERT INTO user_utterances VALUES(?,?,?,?,?,?)',(r['id'],r['canonical_qa_id'],r['text'],r['utterance_kind'],r['runtime_eligibility'],json.dumps(r,sort_keys=True,ensure_ascii=False)));by[r['canonical_qa_id']].append(r['text'])
  if r['utterance_kind']=='exact_reference_fixture':c.execute('INSERT INTO exact_aliases VALUES(?,?)',(norm(r['text']),r['canonical_qa_id']))
 for r in can:c.execute('INSERT INTO canonical_qa_fts VALUES(?,?,?,?,?)',(r['id'],r['title'],r['canonical_question'],r['direct_answer'],' '.join(by[r['id']])))
 for r in sc:c.execute('INSERT INTO multiturn_scenarios VALUES(?,?,?,?,?,?,?,?)',(r['id'],r['canonical_qa_id'],r['experience_level'],r['scenario_type'],r['diagnosis_key'],r['experiment_key'],r['runtime_eligibility'],json.dumps(r,sort_keys=True,ensure_ascii=False)))
 for r in ev:c.execute('INSERT INTO retrieval_evaluations VALUES(?,?,?,?,?,?,?)',(r['id'],r['canonical_qa_id'],r['evaluation_type'],r['query'],int(r['expected_top_1']),r['runtime_eligibility'],json.dumps(r,sort_keys=True,ensure_ascii=False)))
 for table,rs,key in [('contradictions',contr,'topic'),('myths_and_antipatterns',myths,'myth')]:
  for r in rs:c.execute(f'INSERT INTO {table} VALUES(?,?,?,?)',(r['id'],r[key],r['runtime_eligibility'],json.dumps(r,sort_keys=True,ensure_ascii=False)))
 for table,rs in [('claim_candidates',claims),('strategy_candidates',strategies)]:
  for r in rs:c.execute(f'INSERT INTO {table} VALUES(?,?,?,?)',(r['id'],r['canonical_qa_id'],r['runtime_eligibility'],json.dumps(r,sort_keys=True,ensure_ascii=False)))
 for r in proc:c.execute('INSERT INTO logic_procedure_candidates VALUES(?,?,?)',(r['id'],r['runtime_eligibility'],json.dumps(r,sort_keys=True,ensure_ascii=False)))
 for r in sources:c.execute('INSERT INTO sources VALUES(?,?,?,?,?)',(r['id'],r['title'],r['source_type'],r['runtime_eligibility'],json.dumps(r,sort_keys=True,ensure_ascii=False)))
 for r in prov:c.execute('INSERT INTO provenance VALUES(?,?,?,?)',(r['id'],r['record_id'],r['runtime_eligibility'],json.dumps(r,sort_keys=True,ensure_ascii=False)))
 con.commit();print('Integrity:',con.execute('PRAGMA integrity_check').fetchone()[0]);con.close();print('Built',db)
if __name__=='__main__':main()
