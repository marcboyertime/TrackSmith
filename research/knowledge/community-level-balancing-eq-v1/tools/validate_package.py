#!/usr/bin/env python3
import hashlib, json, sqlite3, sys, zipfile
from pathlib import Path
root=Path(__file__).parents[1]
def rows(p):
 return [json.loads(x) for x in (root/p).read_text(encoding='utf-8').splitlines() if x.strip()]
canon=rows('corpus/canonical_qa.jsonl'); utt=rows('corpus/user_utterances.jsonl'); scen=rows('corpus/multiturn_scenarios.jsonl'); sources=rows('research/source_registry.jsonl')
errs=[]
def uniq(name,vals):
 if len(vals)!=len(set(vals)): errs.append(f'duplicate {name}')
uniq('canonical ids',[x['id'] for x in canon]); uniq('utterance ids',[x['id'] for x in utt]); uniq('scenario ids',[x['id'] for x in scen]); uniq('source ids',[x['source_id'] for x in sources])
cids={x['id'] for x in canon}; sids={x['source_id'] for x in sources}
for x in canon:
 if x.get('review_status')!='candidate_not_yet_human_reviewed': errs.append('bad review status '+x['id'])
 for s in x.get('source_ids',[]):
  if s not in sids: errs.append(f'missing source {s} in {x["id"]}')
for x in utt:
 if x['canonical_id'] not in cids: errs.append('orphan utterance '+x['id'])
for x in scen:
 if x['canonical_id'] not in cids: errs.append('orphan scenario '+x['id'])
if len(canon)<200: errs.append('canonical count below 200')
if len(utt)<3000: errs.append('utterance count below 3000')
if len(scen)<600: errs.append('scenario count below 600')
if not any(x['domain']=='level_balancing' for x in canon): errs.append('no level domain')
if not any(x['domain']=='equalization' for x in canon): errs.append('no eq domain')
con=sqlite3.connect(root/'database/tracksmith_level_eq_knowledge.sqlite3')
for query in ['muddy vocal','master clipping','eq before compression','bass buried','fader automation']:
 match=' OR '.join(query.split()); n=con.execute('SELECT count(*) FROM utterance_fts WHERE utterance_fts MATCH ?',(match,)).fetchone()[0]
 if n==0: errs.append('no FTS result '+query)
con.close()
print(f'Canonical: {len(canon)}'); print(f'Utterances: {len(utt)}'); print(f'Scenarios: {len(scen)}'); print(f'Sources: {len(sources)}')
if errs:
 print('FAIL'); print('\n'.join(errs)); sys.exit(1)
print('PASS')
