#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, os, shutil, subprocess, sys, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
M=json.loads((ROOT/'package_manifest.json').read_text())
ALLOWED=('id','package_id','domain','subdomain','title','canonical_question','direct_answer','problem_summary','user_intent','key_distinction','recommended_first_experiment','clarification_questions','competing_hypotheses','evidence_needed','tradeoffs','non_processing_possibilities','teaching_principle','retrieval_tags','source_ids','evidence_class','review_state','native_review_state','original_review_state','original_verification_status','runtime_eligibility')
FORBIDDEN={'logic_guidance','logic_procedure_status','logic_verification_status','location','steps','show_me_query','visual_target_query','verification_status','procedure_id','execution_authority','scenario_type','messages','evaluation_type','expected_canonical_ids','expected_top_1'}
def read_jsonl(p):
 with p.open(encoding='utf-8') as f: return [json.loads(x) for x in f if x.strip()]
def atomic(path,obj):
 path.parent.mkdir(parents=True,exist_ok=True); data=json.dumps(obj,indent=2,sort_keys=True,ensure_ascii=False)+'\n'; fd,tmp=tempfile.mkstemp(dir=path.parent,prefix=path.name+'.')
 try:
  with os.fdopen(fd,'w',encoding='utf-8') as h: h.write(data); h.flush(); os.fsync(h.fileno())
  os.replace(tmp,path)
 finally:
  if os.path.exists(tmp): os.unlink(tmp)
def projection():
 out=[]
 for r in read_jsonl(ROOT/'corpus/canonical_qa.jsonl'):
  item={k:r[k] for k in ALLOWED if k in r}
  text=json.dumps(item,ensure_ascii=False)
  if any(k in item for k in FORBIDDEN) or 'corpus.sqlite' in text or ' > ' in text: raise SystemExit('runtime projection purity failure')
  out.append(item)
 return out
def main():
 ap=argparse.ArgumentParser(); ap.add_argument('--target',required=True); ap.add_argument('--dry-run',action='store_true'); ap.add_argument('--force',action='store_true'); ap.add_argument('--dependency-map'); ap.add_argument('--allow-missing-dependencies',action='store_true'); args=ap.parse_args()
 target=Path(args.target).expanduser().resolve()
 if not (target/'.git').exists(): raise SystemExit('Target is not a Git checkout.')
 subprocess.run([sys.executable,str(ROOT/'tools/validate_package.py')],check=True)
 regpath=target/'research/community_knowledge/package_registry.json'
 reg=json.loads(regpath.read_text()) if regpath.exists() else {'contract':'tracksmith-community-package-registry','version':'1.0','packages':[]}
 installed={x.get('package_id') for x in reg.get('packages',[])}
 missing=set(M['depends_on'])-installed
 if missing and not args.allow_missing_dependencies: raise SystemExit('Missing dependencies: '+', '.join(sorted(missing)))
 proj=projection(); packages_root=target/'research/community_knowledge/packages'; dest=packages_root/M['package_id']; runtime=target/'research/community_knowledge/runtime/pkg013_sends_buses_auxes_track_stacks_groups_submixes.runtime.jsonl'
 plan={'status':'dry_run' if args.dry_run else 'planned','package_id':M['package_id'],'destination':str(dest),'runtime_projection':str(runtime),'runtime_records':len(proj),'excluded_runtime_categories':['logic procedures','Logic navigation','evaluations','multi-turn scenarios','SQLite databases','tests'],'missing_dependencies':sorted(missing)}
 print(json.dumps(plan,indent=2,sort_keys=True))
 if args.dry_run:return
 if dest.exists() and not args.force: raise SystemExit('Destination exists; use --force for intentional replacement.')
 packages_root.mkdir(parents=True,exist_ok=True); tmp=packages_root/f'.{M["package_id"]}.importing-{os.getpid()}'
 if tmp.exists(): shutil.rmtree(tmp)
 shutil.copytree(ROOT,tmp,ignore=shutil.ignore_patterns('__pycache__','*.zip','.DS_Store'))
 if dest.exists(): shutil.rmtree(dest)
 os.replace(tmp,dest)
 runtime.parent.mkdir(parents=True,exist_ok=True)
 fd,tname=tempfile.mkstemp(dir=runtime.parent,prefix=runtime.name+'.')
 with os.fdopen(fd,'w',encoding='utf-8') as h:
  for r in proj: h.write(json.dumps(r,sort_keys=True,ensure_ascii=False)+'\n')
  h.flush(); os.fsync(h.fileno())
 os.replace(tname,runtime)
 entries=[x for x in reg.get('packages',[]) if x.get('package_id')!=M['package_id']]
 entries.append({'package_id':M['package_id'],'package_number':M['package_number'],'package_version':M['package_version'],'contract_version':M['contract_version'],'path':str(dest.relative_to(target)),'runtime_projection':str(runtime.relative_to(target)),'runtime_record_count':len(proj),'review_state':M['review_state'],'logic_procedure_status':M['logic_procedure_status'],'depends_on':M['depends_on']})
 reg['packages']=sorted(entries,key=lambda x:(x.get('package_number',999),x.get('package_id',''))); atomic(regpath,reg)
 atomic(target/f'research/community_knowledge/import_report_{M["package_id"]}.json',{**plan,'status':'staged'})
 print('Staged package and runtime projection.')
if __name__=='__main__':main()
