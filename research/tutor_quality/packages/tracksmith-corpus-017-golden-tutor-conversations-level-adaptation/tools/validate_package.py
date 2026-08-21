#!/usr/bin/env python3
from __future__ import annotations
import argparse,hashlib,json,re,sqlite3,subprocess,sys,tempfile,unicodedata,zipfile
from collections import Counter,defaultdict
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
PID='tracksmith-corpus-017-golden-tutor-conversations-level-adaptation';NS='pkg017';LEVELS={'noob','amateur','pro'}
REQ_DIRS={'integration','corpus','knowledge_candidates','sources','schemas','database','tools','tests','reports','examples'}
REQ_FILES={'README.md','package_manifest.json','PACKAGE_SHA256SUMS.txt','integration/START_HERE_FOR_CODEX.md','integration/PACKAGE_SEQUENCE.md','integration/TRACKSMITH_IMPORT_PLAN.md','integration/REVIEW_CHECKLIST.md','integration/TOOL_CONTRACT.md','integration/integration_manifest.json','corpus/canonical_qa.jsonl','corpus/user_utterances.jsonl','corpus/multiturn_scenarios.jsonl','corpus/retrieval_evaluations.jsonl','corpus/contradictions.jsonl','corpus/myths_and_antipatterns.jsonl','knowledge_candidates/claims.jsonl','knowledge_candidates/strategies.jsonl','knowledge_candidates/logic_procedures.jsonl','sources/source_registry.jsonl','sources/source_access_manifest.json','sources/provenance_manifest.jsonl','database/corpus.sqlite','database/database_manifest.json','tools/build_database.py','tools/validate_package.py','tools/query_corpus.py','tools/inspect_package.py','tools/import_to_tracksmith.py','tests/retrieval_cases.jsonl','tests/integrity_cases.jsonl','tests/expected_statistics.json','reports/COVERAGE_REPORT.md','reports/SOURCE_REPORT.md','reports/QUALITY_BOUNDARIES.md','reports/VALIDATION_REPORT.md','examples/example_canonical_record.json','examples/example_multiturn_scenario.json','examples/example_queries.md','schemas/canonical_qa.schema.json','schemas/user_utterance.schema.json','schemas/multiturn_scenario.schema.json','schemas/retrieval_evaluation.schema.json','schemas/contradiction.schema.json','schemas/myth.schema.json','schemas/claim_candidate.schema.json','schemas/strategy_candidate.schema.json','schemas/logic_procedure_candidate.schema.json'}
EXPECTED={'canonical_qa':180,'user_utterances':2340,'multiturn_scenarios':540,'retrieval_evaluations':900,'contradictions':36,'myths_and_antipatterns':42,'claims':180,'strategies':180,'logic_procedures':0,'sources':25,'provenance':180}
def fail(x):print('FAIL:',x,file=sys.stderr);raise SystemExit(1)
def rows(rel):
 with (ROOT/rel).open(encoding='utf-8') as f:return [json.loads(x) for x in f if x.strip()]
def norm(s):
 s=unicodedata.normalize('NFKC',s).casefold().replace('’',"'")
 return ' '.join(re.sub(r'[^a-z0-9]+',' ',s).split())
def sha(p):
 h=hashlib.sha256();
 with p.open('rb') as f:
  for c in iter(lambda:f.read(1024*1024),b''):h.update(c)
 return h.hexdigest()
def package_ids(path):
 if not path:return set()
 path=Path(path);out=set();items=[path] if path.is_file() else list(path.iterdir())
 legacy={'TrackSmith_Vocal_Quantization_QA_Corpus_v1.zip':'tracksmith-corpus-001-vocal-quantization','TrackSmith_Level_Balancing_EQ_QA_Corpus_v1.zip':'tracksmith-corpus-002-level-balancing-eq','TrackSmith_Compression_Arrangement_Frequency_Allocation_QA_Corpus_v1.zip':'tracksmith-corpus-003-compression-arrangement-frequency-allocation','TrackSmith_Reverb_Delay_QA_Corpus_v1.zip':'tracksmith-corpus-004-reverb-delay'}
 temps=[]
 for item in items:
  if item.is_file() and item.name in legacy:
   out.add(legacy[item.name]);continue
  roots=[]
  if item.is_file() and item.suffix=='.zip':
   td=tempfile.TemporaryDirectory();temps.append(td)
   try:
    with zipfile.ZipFile(item) as z:
     if z.testzip():continue
     z.extractall(td.name)
    roots=[p.parent for p in Path(td.name).rglob('package_manifest.json')]
   except zipfile.BadZipFile:continue
  elif item.is_dir():roots=[p.parent for p in item.rglob('package_manifest.json')]
  for r in roots:
   try:
    m=json.loads((r/'package_manifest.json').read_text());pid=m.get('package_id')
    if pid:out.add(pid)
   except Exception:pass
 return out
def validate(archive=None,prior=None,target=None,full=False):
 for d in REQ_DIRS:
  if not (ROOT/d).is_dir():fail('missing directory '+d)
 actual={str(p.relative_to(ROOT)) for p in ROOT.rglob('*') if p.is_file() and '__pycache__' not in p.parts}
 if actual!=REQ_FILES:fail(f'file structure mismatch missing={sorted(REQ_FILES-actual)} extra={sorted(actual-REQ_FILES)}')
 m=json.loads((ROOT/'package_manifest.json').read_text());im=json.loads((ROOT/'integration/integration_manifest.json').read_text())
 if m.get('package_id')!=PID or m.get('package_number')!=17 or m.get('id_namespace')!=NS:fail('package identity mismatch')
 if im.get('package_id')!=PID or im.get('sequence')!=17 or im.get('namespace')!=NS:fail('integration identity mismatch')
 data={'canonical_qa':rows('corpus/canonical_qa.jsonl'),'user_utterances':rows('corpus/user_utterances.jsonl'),'multiturn_scenarios':rows('corpus/multiturn_scenarios.jsonl'),'retrieval_evaluations':rows('corpus/retrieval_evaluations.jsonl'),'contradictions':rows('corpus/contradictions.jsonl'),'myths_and_antipatterns':rows('corpus/myths_and_antipatterns.jsonl'),'claims':rows('knowledge_candidates/claims.jsonl'),'strategies':rows('knowledge_candidates/strategies.jsonl'),'logic_procedures':rows('knowledge_candidates/logic_procedures.jsonl'),'sources':rows('sources/source_registry.jsonl'),'provenance':rows('sources/provenance_manifest.jsonl')}
 for k,v in EXPECTED.items():
  if len(data[k])!=v:fail(f'{k} count {len(data[k])} != {v}')
 ids=[]
 for rs in data.values():ids += [r['id'] for r in rs if 'id' in r]
 dup=[x for x,n in Counter(ids).items() if n>1]
 if dup:fail('duplicate ids '+str(dup[:5]))
 qids={r['id'] for r in data['canonical_qa']};sids={r['id'] for r in data['sources']}
 for r in data['canonical_qa']:
  if r.get('runtime_eligibility')!='test_only':fail('canonical runtime leakage '+r['id'])
  if r.get('logic_verification_status')!='not_applicable_evaluation_only':fail('bad logic status '+r['id'])
  if not set(r['source_ids'])<=sids:fail('unresolved source '+r['id'])
 for name in ('user_utterances','multiturn_scenarios','retrieval_evaluations','claims','strategies','provenance'):
  for r in data[name]:
   q=r.get('canonical_qa_id') or r.get('record_id')
   if q not in qids:fail(f'unresolved canonical {name} {r.get("id")}')
   if r.get('runtime_eligibility')!='test_only':fail(f'runtime leakage {name} {r.get("id")}')
 if data['logic_procedures']:fail('Package 017 must contain no Logic procedure candidates')
 by=defaultdict(list)
 for r in data['multiturn_scenarios']:by[r['canonical_qa_id']].append(r)
 for qid,trip in by.items():
  if {r['experience_level'] for r in trip}!=LEVELS or len(trip)!=3:fail('level triplet missing '+qid)
  if len({r['diagnosis_key'] for r in trip})!=1 or len({r['experiment_key'] for r in trip})!=1:fail('diagnosis/experiment drift '+qid)
  resp={r['experience_level']:next(x['text'] for x in r['messages'] if x['role']=='assistant_expected') for r in trip}
  wc={k:len(v.split()) for k,v in resp.items()}
  if not (wc['noob']>=wc['amateur']>=wc['pro']):fail('scaffolding length order '+qid+str(wc))
  if '**Try one reversible test**' not in resp['noob'] or 'Hypothesis:' not in resp['pro']:fail('level style markers missing '+qid)
 exact_u={norm(r['text']):r['canonical_qa_id'] for r in data['user_utterances'] if r['utterance_kind']=='exact_reference_fixture'}
 if len(exact_u)!=180:fail('exact alias count or collision')
 exact_e=[r for r in data['retrieval_evaluations'] if r['evaluation_type']=='exact_unique']
 if len(exact_e)!=180:fail('exact evaluation count')
 con=sqlite3.connect(ROOT/'database/corpus.sqlite')
 if con.execute('PRAGMA integrity_check').fetchone()[0]!='ok':fail('database integrity')
 for r in exact_e:
  got=con.execute('SELECT canonical_qa_id FROM exact_aliases WHERE normalized_alias=?',(norm(r['query']),)).fetchone()
  if not got or [got[0]]!=r['expected_canonical_ids']:fail('exact retrieval failure '+r['id'])
 con.close()
 sums={}
 for line in (ROOT/'PACKAGE_SHA256SUMS.txt').read_text().splitlines():
  if line.strip():
   h,rel=line.split('  ',1);sums[rel]=h
 for rel,h in sums.items():
  if not (ROOT/rel).exists() or sha(ROOT/rel)!=h:fail('checksum mismatch '+rel)
 if set(im['file_hashes'])!=set(actual)-{'PACKAGE_SHA256SUMS.txt','integration/integration_manifest.json'}:fail('integration hash scope mismatch')
 for rel,h in im['file_hashes'].items():
  if sha(ROOT/rel)!=h:fail('integration hash mismatch '+rel)
 contract=im.get('experience_level_contract',{})
 if contract.get('default')!='amateur' or set(contract.get('levels',{}))!=LEVELS:fail('experience level contract mismatch')
 if not contract.get('explicit_selection_only') or contract.get('inference_allowed'):fail('level inference policy unsafe')
 if not im.get('evaluation_isolation',{}).get('golden_expected_text_runtime_forbidden'):fail('golden isolation absent')
 if archive:
  with zipfile.ZipFile(archive) as z:
   bad=z.testzip()
   if bad:fail('archive CRC '+bad)
 if prior:
  available=package_ids(prior);missing=set(m['depends_on'])-available
  if missing:fail('missing prerequisites '+', '.join(sorted(missing)))
 if target:
  t=Path(target)
  if not (t/'.git').exists():fail('target is not a Git checkout')
  if full:subprocess.run([sys.executable,str(ROOT/'tools/import_to_tracksmith.py'),'--target',str(t),'--dry-run','--allow-missing-dependencies'],check=True)
 print('PASS')
 print(json.dumps({'canonical':180,'scenarios':540,'levels':sorted(LEVELS),'exact_unique':180,'diagnostic_only':720,'runtime_records':0,'database_integrity':'ok'},indent=2))
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--archive');ap.add_argument('--prior-packages');ap.add_argument('--target');ap.add_argument('--full',action='store_true');a=ap.parse_args();validate(a.archive,a.prior_packages,a.target,a.full)
if __name__=='__main__':main()
