#!/usr/bin/env python3
from __future__ import annotations
import json, shutil, sqlite3
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
DB=ROOT/'corpus/tracksmith_compression_arrangement_frequency_knowledge.sqlite3'
if DB.exists(): DB.unlink()
conn=sqlite3.connect(DB)
conn.executescript('''
CREATE TABLE metadata(key TEXT PRIMARY KEY,value TEXT NOT NULL);
CREATE TABLE canonical(id TEXT PRIMARY KEY,domain TEXT NOT NULL,category TEXT NOT NULL,subcategory TEXT NOT NULL,question TEXT NOT NULL,title TEXT NOT NULL,body TEXT NOT NULL,source_ids_json TEXT NOT NULL,review_status TEXT NOT NULL);
CREATE VIRTUAL TABLE canonical_fts USING fts5(id UNINDEXED,domain,category,question,title,body,tokenize='unicode61 remove_diacritics 2');
CREATE TABLE utterances(utterance_id TEXT PRIMARY KEY,canonical_id TEXT NOT NULL,domain TEXT NOT NULL,text TEXT NOT NULL);
CREATE VIRTUAL TABLE utterances_fts USING fts5(utterance_id UNINDEXED,canonical_id UNINDEXED,domain,text,tokenize='unicode61 remove_diacritics 2');
CREATE TABLE sources(source_id TEXT PRIMARY KEY,tier TEXT NOT NULL,source_type TEXT NOT NULL,title TEXT NOT NULL,publisher TEXT NOT NULL,url TEXT NOT NULL);
CREATE TABLE contradictions(id TEXT PRIMARY KEY,domain TEXT NOT NULL,topic TEXT NOT NULL,position_a TEXT NOT NULL,position_b TEXT NOT NULL,decider TEXT NOT NULL);
''')
for k,v in {'package_name':'TrackSmith_Compression_Arrangement_Frequency_Allocation_QA_Corpus_v1','package_version':'1.0.0','package_sequence':'3','generated_at':'2026-08-11','review_status':'candidate_not_yet_human_reviewed','integrate_after':'TrackSmith_Level_Balancing_EQ_QA_Corpus_v1'}.items(): conn.execute('insert into metadata values (?,?)',(k,v))
with (ROOT/'corpus/canonical_qa.jsonl').open(encoding='utf-8') as f:
  for line in f:
    r=json.loads(line)
    body='\n'.join([r['rationale'],r['teaching_principle'],' '.join(r['clarification_questions']),' '.join(h['mechanism'] for h in r['candidate_hypotheses']),r['recommended_first_experiment']['action'],' '.join(r['what_to_listen_for']),' '.join(r['starting_points']),' '.join(r['user_language_aliases'])])
    row=(r['id'],r['domain'],r['category'],r['subcategory'],r['canonical_user_question'],r['title'],body,json.dumps(r['source_ids']),r['review_status'])
    conn.execute('insert into canonical values (?,?,?,?,?,?,?,?,?)',row)
    conn.execute('insert into canonical_fts values (?,?,?,?,?,?)',(r['id'],r['domain'],r['category'],r['canonical_user_question'],r['title'],body))
with (ROOT/'corpus/user_utterances.jsonl').open(encoding='utf-8') as f:
  for line in f:
    u=json.loads(line); conn.execute('insert into utterances values (?,?,?,?)',(u['utterance_id'],u['canonical_id'],u['domain'],u['text'])); conn.execute('insert into utterances_fts values (?,?,?,?)',(u['utterance_id'],u['canonical_id'],u['domain'],u['text']))
with (ROOT/'research/source_registry.jsonl').open(encoding='utf-8') as f:
  for line in f:
    s=json.loads(line); conn.execute('insert into sources values (?,?,?,?,?,?)',(s['source_id'],s['evidence_tier'],s['source_type'],s['title'],s['publisher'],s['url']))
with (ROOT/'research/contradictions.jsonl').open(encoding='utf-8') as f:
  for line in f:
    c=json.loads(line); conn.execute('insert into contradictions values (?,?,?,?,?,?)',(c['id'],c['domain'],c['topic'],c['position_a'],c['position_b'],c['what_determines_which_applies']))
conn.commit(); conn.execute('vacuum'); conn.close()
shutil.copy2(DB,ROOT/'database/tracksmith_compression_arrangement_frequency_knowledge.sqlite3')
print('rebuilt',DB)
