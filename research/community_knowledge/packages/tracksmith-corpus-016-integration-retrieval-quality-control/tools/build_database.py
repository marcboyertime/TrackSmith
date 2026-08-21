#!/usr/bin/env python3
from __future__ import annotations
import json, sqlite3
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; DB=ROOT/'database/corpus.sqlite'

def read_jsonl(path):
    if not path.exists(): return []
    return [json.loads(x) for x in path.read_text(encoding='utf-8').splitlines() if x.strip()]

def main():
    m=json.loads((ROOT/'package_manifest.json').read_text())
    access=json.loads((ROOT/'sources/source_access_manifest.json').read_text())
    if DB.exists():DB.unlink()
    c=sqlite3.connect(DB); cur=c.cursor()
    cur.executescript('''
    PRAGMA journal_mode=DELETE;
    CREATE TABLE packages(package_id TEXT PRIMARY KEY,package_number INTEGER,contract_version TEXT,package_version TEXT,manifest_json TEXT);
    CREATE TABLE canonical_qa(id TEXT PRIMARY KEY,package_id TEXT,domain TEXT,subdomain TEXT,topic TEXT,title TEXT,canonical_question TEXT,direct_answer TEXT,recommended_first_experiment TEXT,review_state TEXT,source_ids_json TEXT,record_json TEXT);
    CREATE TABLE user_utterances(id TEXT PRIMARY KEY,canonical_qa_id TEXT,text TEXT,variant_type TEXT,record_json TEXT);
    CREATE TABLE multiturn_scenarios(id TEXT PRIMARY KEY,canonical_qa_id TEXT,scenario_type TEXT,record_json TEXT);
    CREATE TABLE retrieval_evaluations(id TEXT PRIMARY KEY,canonical_qa_id TEXT,evaluation_type TEXT,query TEXT,record_json TEXT);
    CREATE TABLE contradictions(id TEXT PRIMARY KEY,topic TEXT,position_a TEXT,position_b TEXT,record_json TEXT);
    CREATE TABLE myths_and_antipatterns(id TEXT PRIMARY KEY,myth TEXT,correction TEXT,record_json TEXT);
    CREATE TABLE claim_candidates(id TEXT PRIMARY KEY,canonical_qa_id TEXT,claim_text TEXT,review_state TEXT,record_json TEXT);
    CREATE TABLE strategy_candidates(id TEXT PRIMARY KEY,canonical_qa_id TEXT,label TEXT,review_state TEXT,record_json TEXT);
    CREATE TABLE logic_procedure_candidates(id TEXT PRIMARY KEY,canonical_qa_id TEXT,title TEXT,verification_status TEXT,review_state TEXT,record_json TEXT);
    CREATE TABLE sources(id TEXT PRIMARY KEY,title TEXT,publisher_or_community TEXT,canonical_url TEXT,evidence_class TEXT,access_mode TEXT,record_json TEXT);
    CREATE TABLE provenance(id TEXT PRIMARY KEY,canonical_qa_id TEXT,source_ids_json TEXT,record_json TEXT);
    CREATE VIRTUAL TABLE canonical_qa_fts USING fts5(id UNINDEXED,title,canonical_question,direct_answer,experiment,tags,utterances);
    CREATE TABLE integration_policies(key TEXT PRIMARY KEY,value_json TEXT);
    CREATE TABLE audio_datasets(id TEXT PRIMARY KEY,title TEXT,access_mode TEXT,profiles_json TEXT,record_json TEXT);
    ''')
    cur.execute('INSERT INTO packages VALUES (?,?,?,?,?)',(m['package_id'],m['package_number'],m['contract_version'],m['package_version'],json.dumps(m,sort_keys=True)))
    for s in read_jsonl(ROOT/'sources/source_registry.jsonl'):
        cur.execute('INSERT INTO sources VALUES (?,?,?,?,?,?,?)',(s['id'],s['title'],s['publisher_or_community'],s['canonical_url'],s['evidence_class'],s['access_mode'],json.dumps(s,sort_keys=True)))
    cur.execute('INSERT INTO integration_policies VALUES (?,?)',('retrieval_budget',json.dumps({'canonical_max':4,'per_package_max':2,'per_domain_max':2,'contradiction_max':1,'myth_max':2})))
    for ds in access['datasets']:
        cur.execute('INSERT INTO audio_datasets VALUES (?,?,?,?,?)',(ds['id'],ds['title'],ds['access_mode'],json.dumps((ds.get('download') or {}).get('profiles',[])),json.dumps(ds,sort_keys=True)))
    c.commit(); ok=cur.execute('PRAGMA integrity_check').fetchone()[0]; c.close()
    if ok!='ok':raise SystemExit(ok)
    print(f'Built {DB}')
if __name__=='__main__':main()
