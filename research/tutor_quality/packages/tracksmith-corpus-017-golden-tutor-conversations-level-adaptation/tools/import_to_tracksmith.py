#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,os,shutil,subprocess,sys,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];M=json.loads((ROOT/'package_manifest.json').read_text());IM=json.loads((ROOT/'integration/integration_manifest.json').read_text())
def atomic(path,obj):
 path.parent.mkdir(parents=True,exist_ok=True);fd,tmp=tempfile.mkstemp(dir=path.parent,prefix=path.name+'.')
 try:
  with os.fdopen(fd,'w',encoding='utf-8') as f:f.write(json.dumps(obj,indent=2,sort_keys=True,ensure_ascii=False)+'\n');f.flush();os.fsync(f.fileno())
  os.replace(tmp,path)
 finally:
  if os.path.exists(tmp):os.unlink(tmp)
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--target',required=True);ap.add_argument('--dry-run',action='store_true');ap.add_argument('--force',action='store_true');ap.add_argument('--allow-missing-dependencies',action='store_true');a=ap.parse_args();t=Path(a.target).expanduser().resolve()
 if not (t/'.git').exists():raise SystemExit('Target is not a Git checkout.')
 subprocess.run([sys.executable,str(ROOT/'tools/validate_package.py')],check=True)
 regp=t/'research/tutor_quality/package_registry.json';reg=json.loads(regp.read_text()) if regp.exists() else {'contract':'tracksmith-tutor-quality-registry','version':'1.0','packages':[]}
 installed={x.get('package_id') for x in reg.get('packages',[])}
 # Also accept corpus registry dependencies created by Package 016.
 cr=t/'research/community_knowledge/package_registry.json'
 if cr.exists():installed|={x.get('package_id') for x in json.loads(cr.read_text()).get('packages',[])}
 missing=set(M['depends_on'])-installed
 if missing and not a.allow_missing_dependencies:raise SystemExit('Missing dependencies: '+', '.join(sorted(missing)))
 dest=t/'research/tutor_quality/packages'/M['package_id'];contract=t/'research/tutor_quality/experience_level_contract.json'
 plan={'status':'dry_run' if a.dry_run else 'planned','package_id':M['package_id'],'destination':str(dest),'experience_level_contract':str(contract),'runtime_record_count':0,'evaluation_records':M['counts'],'missing_dependencies':sorted(missing),'runtime_exclusions':['golden expected responses','evaluation scenarios','exact aliases','candidate claims and strategies','SQLite database','Logic procedure candidates']}
 print(json.dumps(plan,indent=2,sort_keys=True))
 if a.dry_run:return
 if dest.exists() and not a.force:raise SystemExit('Destination exists; use --force for intentional replacement.')
 dest.parent.mkdir(parents=True,exist_ok=True);tmp=dest.parent/f'.{M["package_id"]}.importing-{os.getpid()}'
 if tmp.exists():shutil.rmtree(tmp)
 shutil.copytree(ROOT,tmp,ignore=shutil.ignore_patterns('__pycache__','*.zip','.DS_Store'))
 if dest.exists():shutil.rmtree(dest)
 os.replace(tmp,dest)
 atomic(contract,IM['experience_level_contract'])
 entries=[x for x in reg.get('packages',[]) if x.get('package_id')!=M['package_id']]
 entries.append({'package_id':M['package_id'],'package_number':17,'package_version':M['package_version'],'path':str(dest.relative_to(t)),'runtime_record_count':0,'evaluation_only':True,'experience_levels':['noob','amateur','pro'],'default_level':'amateur','depends_on':M['depends_on']})
 reg['packages']=sorted(entries,key=lambda x:x.get('package_number',999));atomic(regp,reg)
 atomic(t/f'research/tutor_quality/import_report_{M["package_id"]}.json',{**plan,'status':'staged'})
 print('Staged evaluation package and experience-level contract; emitted no live runtime knowledge.')
if __name__=='__main__':main()
