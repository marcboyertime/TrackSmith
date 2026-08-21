#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, re, sqlite3, sys, tempfile, unicodedata, zipfile
from collections import Counter, defaultdict
from pathlib import Path
from urllib.parse import urlparse

HERE=Path(__file__).resolve().parents[1]
REQUIRED_DIRS={'integration','corpus','knowledge_candidates','sources','schemas','database','tools','tests','reports','examples'}
REQUIRED_FILES={
'README.md','package_manifest.json','PACKAGE_SHA256SUMS.txt','integration/START_HERE_FOR_CODEX.md','integration/PACKAGE_SEQUENCE.md','integration/TRACKSMITH_IMPORT_PLAN.md','integration/REVIEW_CHECKLIST.md','integration/TOOL_CONTRACT.md','integration/integration_manifest.json',
'corpus/canonical_qa.jsonl','corpus/user_utterances.jsonl','corpus/multiturn_scenarios.jsonl','corpus/retrieval_evaluations.jsonl','corpus/contradictions.jsonl','corpus/myths_and_antipatterns.jsonl',
'knowledge_candidates/claims.jsonl','knowledge_candidates/strategies.jsonl','knowledge_candidates/logic_procedures.jsonl','sources/source_registry.jsonl','sources/source_access_manifest.json','sources/provenance_manifest.jsonl',
'database/corpus.sqlite','database/database_manifest.json','tools/build_database.py','tools/validate_package.py','tools/query_corpus.py','tools/inspect_package.py','tools/import_to_tracksmith.py',
'tests/retrieval_cases.jsonl','tests/integrity_cases.jsonl','tests/expected_statistics.json','reports/COVERAGE_REPORT.md','reports/SOURCE_REPORT.md','reports/QUALITY_BOUNDARIES.md','reports/VALIDATION_REPORT.md','examples/example_canonical_record.json','examples/example_multiturn_scenario.json','examples/example_queries.md'}
SCHEMAS={
'canonical_qa':('schemas/canonical_qa.schema.json','corpus/canonical_qa.jsonl'),'user_utterances':('schemas/user_utterance.schema.json','corpus/user_utterances.jsonl'),'multiturn_scenarios':('schemas/multiturn_scenario.schema.json','corpus/multiturn_scenarios.jsonl'),'retrieval_evaluations':('schemas/retrieval_evaluation.schema.json','corpus/retrieval_evaluations.jsonl'),'contradictions':('schemas/contradiction.schema.json','corpus/contradictions.jsonl'),'myths_and_antipatterns':('schemas/myth.schema.json','corpus/myths_and_antipatterns.jsonl'),'claim_candidates':('schemas/claim_candidate.schema.json','knowledge_candidates/claims.jsonl'),'strategy_candidates':('schemas/strategy_candidate.schema.json','knowledge_candidates/strategies.jsonl'),'logic_procedure_candidates':('schemas/logic_procedure_candidate.schema.json','knowledge_candidates/logic_procedures.jsonl')}
STATUS_FIELDS=('review_state','native_review_state','original_review_state','original_verification_status','logic_verification_status','runtime_eligibility')
RUNTIME_ALLOWED={'id','package_id','domain','subdomain','title','canonical_question','direct_answer','problem_summary','user_intent','key_distinction','recommended_first_experiment','clarification_questions','competing_hypotheses','evidence_needed','tradeoffs','non_processing_possibilities','teaching_principle','retrieval_tags','source_ids','evidence_class','review_state','native_review_state','original_review_state','original_verification_status','runtime_eligibility'}
FORBIDDEN_RUNTIME_KEYS={'logic_guidance','logic_procedure_status','logic_verification_status','location','steps','show_me_query','visual_target_query','verification_status','procedure_id','execution_authority','expected_canonical_ids','forbidden_canonical_ids','scenario_type','messages','evaluation_type','expected_top_1','test_fixture'}
FORBIDDEN_RUNTIME_TEXT=(r'corpus\.sqlite',r'Logic[^\n]{0,80}\s>\s',r'choose\s+[^\n]{0,60}\s+from\s+the\s+[^\n]{0,40}menu')
LEGACY_MAP={'TrackSmith_Vocal_Quantization_QA_Corpus_v1.zip':'tracksmith-corpus-001-vocal-quantization','TrackSmith_Level_Balancing_EQ_QA_Corpus_v1.zip':'tracksmith-corpus-002-level-balancing-eq','TrackSmith_Compression_Arrangement_Frequency_Allocation_QA_Corpus_v1.zip':'tracksmith-corpus-003-compression-arrangement-frequency-allocation','TrackSmith_Reverb_Delay_QA_Corpus_v1.zip':'tracksmith-corpus-004-reverb-delay'}

def fail(msg): print('FAIL:',msg,file=sys.stderr); raise SystemExit(1)
def sha(path):
 h=hashlib.sha256();
 with path.open('rb') as f:
  for chunk in iter(lambda:f.read(1024*1024),b''): h.update(chunk)
 return h.hexdigest()
def read_jsonl(root,rel):
 with (root/rel).open(encoding='utf-8') as f: return [json.loads(x) for x in f if x.strip()]
def norm(text):
 text=unicodedata.normalize('NFKC',text).casefold().replace('’',"'")
 text=re.sub(r"[^a-z0-9]+"," ",text); return ' '.join(text.split())
def recursive_forbidden(value,path='root'):
 if isinstance(value,dict):
  for k,v in value.items():
   if k in FORBIDDEN_RUNTIME_KEYS: fail(f'runtime projection forbidden key {path}.{k}')
   recursive_forbidden(v,f'{path}.{k}')
 elif isinstance(value,list):
  for i,v in enumerate(value): recursive_forbidden(v,f'{path}[{i}]')
 elif isinstance(value,str):
  for pat in FORBIDDEN_RUNTIME_TEXT:
   if re.search(pat,value,re.I): fail(f'runtime projection forbidden navigation/database text at {path}: {value[:120]}')
def runtime_projection(rows):
 out=[]
 for row in rows:
  item={k:row[k] for k in RUNTIME_ALLOWED if k in row and k!='logic_verification_status'}
  recursive_forbidden(item)
  out.append(item)
 return out

def legacy_package_id(root,manifest):
 name=(root.name+' '+str(manifest.get('package_name',''))+' '+str(manifest.get('package',''))).lower()
 seq=manifest.get('package_sequence') or manifest.get('counts',{}).get('package_sequence')
 if 'vocal_quantization' in name or ('vocal' in name and 'quantization' in name): return 'tracksmith-corpus-001-vocal-quantization'
 if 'level_balancing_eq' in name or ('level' in name and 'equalization' in name): return 'tracksmith-corpus-002-level-balancing-eq'
 if 'compression_arrangement_frequency' in name or ('compression' in name and 'arrangement' in name and 'frequency' in name): return 'tracksmith-corpus-003-compression-arrangement-frequency-allocation'
 if 'reverb_delay' in name or ('reverb' in name and 'delay' in name): return 'tracksmith-corpus-004-reverb-delay'
 return {1:'tracksmith-corpus-001-vocal-quantization',2:'tracksmith-corpus-002-level-balancing-eq',3:'tracksmith-corpus-003-compression-arrangement-frequency-allocation',4:'tracksmith-corpus-004-reverb-delay'}.get(seq)

def package_roots(path):
 path=Path(path)
 roots=[]; candidates=[]; temps=[]
 if path.is_dir(): candidates=list(path.iterdir())+[path]
 else: candidates=[path]
 for item in candidates:
  if item.is_dir() and ((item/'package_manifest.json').exists() or (item/'manifest.json').exists()): roots.append(item)
  elif item.is_file() and item.suffix=='.zip':
   td=tempfile.TemporaryDirectory(); temps.append(td)
   try:
    with zipfile.ZipFile(item) as z:
     bad=z.testzip()
     if bad: fail(f'prior-package archive CRC failure {item}: {bad}')
     z.extractall(td.name)
    found=list(Path(td.name).rglob('package_manifest.json'))+list(Path(td.name).rglob('manifest.json'))
    for p in found:
     root=p.parent
     if (root/'corpus/canonical_qa.jsonl').exists() and root not in roots: roots.append(root)
   except zipfile.BadZipFile: fail(f'bad prior-package ZIP: {item}')
 return roots,temps

def load_prior(path):
 ids=set(); aliases=defaultdict(set); packages=set(); temps=[]
 if not path: return ids,aliases,packages,temps
 roots,temps=package_roots(path)
 for root in roots:
  modern=(root/'package_manifest.json').exists()
  try: m=json.loads((root/('package_manifest.json' if modern else 'manifest.json')).read_text())
  except Exception: continue
  pid=m.get('package_id') if modern else legacy_package_id(root,m)
  if pid=='tracksmith-corpus-014-sidechain-automation-midi-groove-velocity-transform': continue
  if pid: packages.add(pid)
  rels=(
   'corpus/canonical_qa.jsonl','corpus/user_utterances.jsonl','corpus/multiturn_scenarios.jsonl',
   'corpus/retrieval_evaluations.jsonl','corpus/retrieval_evaluation.jsonl','corpus/evaluation_cases.jsonl',
   'corpus/contradictions.jsonl','research/contradictions.jsonl',
   'corpus/myths_and_antipatterns.jsonl','research/myths_and_antipatterns.jsonl',
   'knowledge_candidates/claims.jsonl','integration/tracksmith_claim_candidates.jsonl',
   'knowledge_candidates/strategies.jsonl','integration/tracksmith_strategy_candidates.jsonl',
   'knowledge_candidates/logic_procedures.jsonl','integration/logic_procedure_candidates.jsonl',
   'sources/source_registry.jsonl','research/source_registry.jsonl','sources/provenance_manifest.jsonl'
  )
  for rel in rels:
   p=root/rel
   if not p.exists(): continue
   for r in read_jsonl(root,rel):
    rid=r.get('id') or r.get('record_id') or r.get('source_id')
    if isinstance(rid,str): ids.add(rid)
    if rel=='corpus/canonical_qa.jsonl' and r.get('canonical_question'):
     rid=r.get('id') or r.get('record_id')
     if rid: aliases[norm(r['canonical_question'])].add(rid)
    if rel=='corpus/user_utterances.jsonl' and r.get('text'):
     qid=r.get('canonical_qa_id') or r.get('canonical_id') or r.get('record_id')
     if qid: aliases[norm(r['text'])].add(qid)
 return ids,aliases,packages,temps

def validate_root(root,prior=None,target=None,full=False):
 for d in REQUIRED_DIRS:
  if not (root/d).is_dir(): fail(f'missing directory {d}')
 for f in REQUIRED_FILES:
  if not (root/f).is_file(): fail(f'missing file {f}')
 manifest=json.loads((root/'package_manifest.json').read_text())
 integ=json.loads((root/'integration/integration_manifest.json').read_text())
 if manifest.get('package_contract')!='tracksmith-corpus-package' or manifest.get('contract_version')!='1.0': fail('package contract mismatch')
 if manifest.get('id_namespace')!='pkg014' or manifest.get('package_number')!=14: fail('namespace/sequence mismatch')
 if integ.get('namespace')!='pkg014' or integ.get('sequence')!=14 or integ.get('package_id')!=manifest.get('package_id'): fail('integration manifest identity mismatch')
 files={k:read_jsonl(root,rel) for k,(_,rel) in SCHEMAS.items()}
 files['sources']=read_jsonl(root,'sources/source_registry.jsonl'); files['provenance']=read_jsonl(root,'sources/provenance_manifest.jsonl')
 all_ids=set()
 for name,rows in files.items():
  expected=manifest['record_counts'][name]
  if len(rows)!=expected: fail(f'{name} count {len(rows)} != {expected}')
  ids=[r['id'] for r in rows]
  if len(ids)!=len(set(ids)): fail(f'duplicate IDs in {name}')
  if any(not x.startswith('pkg014.') for x in ids): fail(f'ID outside pkg014 in {name}')
  if all_ids.intersection(ids): fail(f'cross-file ID collision in {name}')
  all_ids.update(ids)
  if name not in ('sources',):
   for r in rows:
    missing=[k for k in STATUS_FIELDS if k not in r]
    if missing: fail(f'{r.get("id")} missing status fields {missing}')
 for name,(schema_rel,_) in SCHEMAS.items():
  schema=json.loads((root/schema_rel).read_text()); req=schema.get('required',[])
  for r in files[name]:
   miss=[k for k in req if k not in r]
   if miss: fail(f'{name} {r.get("id")} missing {miss}')
 cids={r['id'] for r in files['canonical_qa']}; sids={r['id'] for r in files['sources']}
 if len({norm(r['canonical_question']) for r in files['canonical_qa']})!=len(files['canonical_qa']): fail('duplicate normalized canonical questions')
 if len({norm(r['text']) for r in files['user_utterances']})!=len(files['user_utterances']): fail('duplicate normalized utterances')
 for name in ('user_utterances','multiturn_scenarios','retrieval_evaluations','claim_candidates','strategy_candidates','logic_procedure_candidates','provenance'):
  for r in files[name]:
   if r['canonical_qa_id'] not in cids: fail(f'{name} bad canonical link {r["id"]}')
 for name,rows in files.items():
  for r in rows:
   unknown=set(r.get('source_ids',[]))-sids
   if unknown: fail(f'{r["id"]} unknown sources {sorted(unknown)[:3]}')
 for s in files['sources']:
  p=urlparse(s['canonical_url'])
  if p.scheme not in ('http','https') or not p.netloc: fail(f'invalid source URL {s["id"]}')
 for r in files['logic_procedure_candidates']:
  if r.get('execution_authority') is not False: fail(f'procedure authority true {r["id"]}')
  if r.get('verification_status')!='candidate_unverified_on_installed_logic': fail(f'procedure verification changed {r["id"]}')
  if r.get('runtime_eligibility')!='excluded_from_runtime': fail(f'procedure runtime eligibility wrong {r["id"]}')
 # Exact/diagnostic retrieval contract.
 alias_map=defaultdict(set)
 for r in files['canonical_qa']: alias_map[norm(r['canonical_question'])].add(r['id'])
 for r in files['user_utterances']: alias_map[norm(r['text'])].add(r['canonical_qa_id'])
 exact=[e for e in files['retrieval_evaluations'] if e.get('retrieval_classification')=='exact_unique']
 if len(exact)!=len(files['canonical_qa']): fail('must have exactly one exact fixture per canonical')
 for e in files['retrieval_evaluations']:
  cls=e.get('retrieval_classification','')
  if cls=='exact_unique':
   if e.get('diagnostic_only') or e.get('retrieval_expectation')!='expected_top_1': fail(f'exact fixture misclassified {e["id"]}')
   mapped=alias_map[norm(e['query'])]
   if mapped!={e['canonical_qa_id']}: fail(f'exact fixture is ambiguous {e["id"]}: {sorted(mapped)}')
  else:
   if not e.get('diagnostic_only') or e.get('retrieval_expectation')!='diagnostic_only': fail(f'non-exact fixture claims top1 {e["id"]}')
 # DB and exact top-1.
 db=sqlite3.connect(root/'database/corpus.sqlite');
 if db.execute('PRAGMA integrity_check').fetchone()[0]!='ok': fail('SQLite integrity failure')
 for name in ('canonical_qa','user_utterances','multiturn_scenarios','retrieval_evaluations','contradictions','myths_and_antipatterns','claim_candidates','strategy_candidates','logic_procedure_candidates','sources','provenance'):
  if db.execute(f'SELECT count(*) FROM {name}').fetchone()[0]!=len(files[name]): fail(f'database count mismatch {name}')
 for e in exact:
  rows=db.execute('SELECT id,bm25(canonical_qa_fts) AS score FROM canonical_qa_fts WHERE canonical_qa_fts MATCH ? ORDER BY score LIMIT 2',(norm(e['query']),)).fetchall()
  if not rows or rows[0][0]!=e['canonical_qa_id']: fail(f'exact fixture top1 failed {e["id"]}: {rows[:2]}')
 db.close()
 # Runtime projection purity.
 projection=runtime_projection(files['canonical_qa'])
 if len(projection)!=len(files['canonical_qa']): fail('runtime projection count mismatch')
 # Integration manifest paths/counts/statuses.
 if integ.get('counts')!=manifest.get('record_counts'): fail('integration counts mismatch')
 if set(integ.get('prerequisites',[]))!=set(manifest.get('depends_on',[])): fail('integration prerequisites mismatch')
 if 'integration/integration_manifest.json' not in REQUIRED_FILES: fail('internal validator bug')
 declared_native=set(integ.get('native_review_states',[]))
 if 'candidate_not_yet_human_reviewed' not in declared_native: fail('native review states missing')
 for field in STATUS_FIELDS:
  if field not in integ.get('preserved_status_fields',[]): fail(f'integration manifest does not preserve {field}')
 test_only=set(integ.get('test_only_files',[]))
 required_test={'corpus/multiturn_scenarios.jsonl','corpus/retrieval_evaluations.jsonl','knowledge_candidates/logic_procedures.jsonl','database/corpus.sqlite','tests/retrieval_cases.jsonl'}
 if not required_test.issubset(test_only): fail('test-only file declaration incomplete')
 # File hashes declared in integration manifest, excluding circular/self checksum files.
 for rel,digest in integ.get('file_hashes',{}).items():
  p=root/rel
  if not p.is_file() or sha(p)!=digest: fail(f'integration file hash mismatch {rel}')
 # Package checksum manifest.
 lines=[x for x in (root/'PACKAGE_SHA256SUMS.txt').read_text().splitlines() if x.strip()]
 checked=set()
 for line in lines:
  digest,rel=line.split('  ',1); p=root/rel
  if not p.is_file() or sha(p)!=digest: fail(f'package checksum mismatch {rel}')
  checked.add(rel)
 expected={str(p.relative_to(root)) for p in root.rglob('*') if p.is_file() and p.name!='PACKAGE_SHA256SUMS.txt' and '__pycache__' not in p.parts}
 if checked!=expected: fail(f'checksum coverage mismatch missing={sorted(expected-checked)[:4]} extra={sorted(checked-expected)[:4]}')
 # Additive compatibility and collisions.
 prior_ids,prior_aliases,prior_pids,temps=load_prior(prior)
 try:
  overlap=all_ids.intersection(prior_ids)
  if overlap: fail(f'cross-package ID collisions: {sorted(overlap)[:5]}')
  missing=set(manifest.get('depends_on',[]))-prior_pids if prior else set()
  if prior and missing: fail(f'missing prior packages: {sorted(missing)}')
  exact_collisions=[]
  for e in exact:
   if norm(e['query']) in prior_aliases: exact_collisions.append({'fixture_id':e['id'],'prior_ids':sorted(prior_aliases[norm(e['query'])])})
  mapped={m.get('incoming_fixture_id') for m in integ.get('collision_mappings',[]) if m.get('collision_type')=='exact_normalized_alias'}
  unresolved=[c for c in exact_collisions if c['fixture_id'] not in mapped]
  if unresolved: fail(f'unmapped cross-package exact alias collisions: {unresolved[:3]}')
 finally:
  for t in temps: t.cleanup()
 # Target package registry prerequisite check.
 if target:
  reg=Path(target)/'research/community_knowledge/package_registry.json'
  if not reg.exists(): fail(f'target registry missing: {reg}')
  installed={p.get('package_id') for p in json.loads(reg.read_text()).get('packages',[])}
  missing=set(manifest['depends_on'])-installed
  if missing: fail(f'target missing prerequisites: {sorted(missing)}')
 report={'status':'PASS','package_id':manifest['package_id'],'counts':manifest['record_counts'],'exact_unique_fixtures':len(exact),'diagnostic_fixtures':len(files['retrieval_evaluations'])-len(exact),'runtime_projection_records':len(projection),'prior_package_check':bool(prior),'target_check':bool(target),'database_integrity':'ok'}
 print('PASS'); print(json.dumps(report,indent=2,sort_keys=True)); return report

def main():
 ap=argparse.ArgumentParser(); ap.add_argument('--archive'); ap.add_argument('--prior-packages'); ap.add_argument('--target'); ap.add_argument('--full',action='store_true'); args=ap.parse_args()
 if args.archive:
  with tempfile.TemporaryDirectory() as td:
   with zipfile.ZipFile(args.archive) as z:
    bad=z.testzip();
    if bad: fail(f'archive CRC failure {bad}')
    z.extractall(td)
   roots=list(Path(td).rglob('package_manifest.json'))
   if len(roots)!=1: fail(f'archive must contain one package root, found {len(roots)}')
   validate_root(roots[0].parent,args.prior_packages,args.target,args.full)
 else: validate_root(HERE,args.prior_packages,args.target,args.full)
if __name__=='__main__': main()
