#!/usr/bin/env python3
from __future__ import annotations

import argparse
import contextlib
import hashlib
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
import zipfile
from collections import Counter, defaultdict
from pathlib import Path, PurePosixPath
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
M = json.loads((ROOT / 'package_manifest.json').read_text(encoding='utf-8'))
AUDIO = json.loads((ROOT / 'sources/source_access_manifest.json').read_text(encoding='utf-8'))

LEGACY_ARCHIVES = {
    1: ('TrackSmith_Vocal_Quantization_QA_Corpus_v1.zip', 'tracksmith-corpus-001-vocal-quantization'),
    2: ('TrackSmith_Level_Balancing_EQ_QA_Corpus_v1.zip', 'tracksmith-corpus-002-level-balancing-eq'),
    3: ('TrackSmith_Compression_Arrangement_Frequency_Allocation_QA_Corpus_v1.zip', 'tracksmith-corpus-003-compression-arrangement-frequency-allocation'),
    4: ('TrackSmith_Reverb_Delay_QA_Corpus_v1.zip', 'tracksmith-corpus-004-reverb-delay'),
}
REQUIRED_IDS = M['depends_on']
ALLOWED_CANONICAL_RUNTIME = (
    'id','package_id','domain','subdomain','title','canonical_question','direct_answer','problem_summary','user_intent',
    'key_distinction','recommended_first_experiment','clarification_questions','competing_hypotheses','evidence_needed',
    'tradeoffs','non_processing_possibilities','teaching_principle','retrieval_tags','source_ids','evidence_class',
    'review_state','native_review_state','original_review_state','original_verification_status','runtime_eligibility'
)
ALLOWED_UTTERANCE_RUNTIME = (
    'id','canonical_qa_id','package_id','domain','subdomain','text','variant_type','retrieval_tags','review_state',
    'native_review_state','original_review_state','original_verification_status','runtime_eligibility'
)
FORBIDDEN_RUNTIME_KEYS = {
    'logic_guidance','logic_procedure_status','logic_verification_status','location','steps','show_me_query','visual_target_query',
    'verification_status','procedure_id','execution_authority','scenario_type','messages','evaluation_type',
    'expected_canonical_ids','expected_top_1','retrieval_expectation','test_fixture','exact_fixture','sqlite_path','database_path'
}
EXACT_PREFIX = 'TrackSmith exact Package {number:03d} reference exactpkg{number:03d}qa{index:06d}'


def read_jsonl_bytes(data: bytes) -> list[dict]:
    return [json.loads(line) for line in data.decode('utf-8').splitlines() if line.strip()]


def read_jsonl(path: Path) -> list[dict]:
    if not path.exists(): return []
    with path.open(encoding='utf-8') as f:
        return [json.loads(line) for line in f if line.strip()]


def write_jsonl(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('w', encoding='utf-8') as f:
        for r in rows:
            f.write(json.dumps(r, sort_keys=True, ensure_ascii=False) + '\n')


def atomic_json(path: Path, obj: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    data = json.dumps(obj, indent=2, sort_keys=True, ensure_ascii=False) + '\n'
    fd, temp = tempfile.mkstemp(dir=path.parent, prefix=path.name + '.')
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as f:
            f.write(data); f.flush(); os.fsync(f.fileno())
        os.replace(temp, path)
    finally:
        if os.path.exists(temp): os.unlink(temp)


def sha256_file(path: Path) -> str:
    h=hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda:f.read(1024*1024), b''): h.update(chunk)
    return h.hexdigest()


def checksum_file(path: Path, kind: str) -> str:
    h=hashlib.new(kind)
    with path.open('rb') as f:
        for chunk in iter(lambda:f.read(1024*1024), b''): h.update(chunk)
    return h.hexdigest()


def norm(text: str) -> str:
    text = text.casefold().replace('’', "'")
    text = re.sub(r"[^\w]+", ' ', text, flags=re.UNICODE)
    return ' '.join(text.split())


def tokens(text: str) -> list[str]:
    return [t for t in norm(text).split() if len(t) > 1]


def text_value(value: Any) -> str:
    if value is None:
        return ''
    if isinstance(value, str):
        return value
    return json.dumps(value, sort_keys=True, ensure_ascii=False)


def package_root(z: zipfile.ZipFile) -> str:
    roots={n.split('/')[0] for n in z.namelist() if n and not n.startswith('__MACOSX/')}
    if len(roots)!=1: raise ValueError(f'Archive must contain one root directory; found {sorted(roots)}')
    return next(iter(roots))


def zjson(z: zipfile.ZipFile, root: str, rel: str) -> Any:
    return json.loads(z.read(f'{root}/{rel}'))


def zjsonl(z: zipfile.ZipFile, root: str, candidates: list[str]) -> list[dict]:
    names=set(z.namelist())
    for rel in candidates:
        q=f'{root}/{rel}'
        if q in names: return read_jsonl_bytes(z.read(q))
    return []


def sidecar_ok(path: Path) -> tuple[bool, str|None]:
    side=Path(str(path)+'.sha256')
    if not side.exists(): return True, None
    expected=side.read_text(encoding='utf-8').strip().split()[0]
    actual=sha256_file(path)
    return expected==actual, expected


def inspect_archive(path: Path) -> dict:
    with zipfile.ZipFile(path) as z:
        root=package_root(z); names=set(z.namelist())
        if f'{root}/package_manifest.json' in names:
            m=zjson(z,root,'package_manifest.json')
            pid=m.get('package_id'); number=int(m.get('package_number',0)); modern=True
            version=m.get('package_version','1.0.0')
        else:
            number=next((n for n,(filename,_) in LEGACY_ARCHIVES.items() if filename==path.name),0)
            pid=LEGACY_ARCHIVES.get(number,(None,None))[1]
            m=zjson(z,root,'manifest.json'); modern=False
            version=m.get('package_version') or m.get('version','1.0.0')
        return {'path':path,'root':root,'package_id':pid,'package_number':number,'package_version':version,'modern':modern,'file_count':sum(not n.endswith('/') for n in names),'manifest':m}


def discover_packages(directory: Path) -> tuple[list[dict], list[dict]]:
    candidates=[]
    for path in sorted(directory.rglob('*.zip')):
        try:
            info=inspect_archive(path)
        except Exception:
            continue
        if info['package_id']:
            ok,_=sidecar_ok(path)
            if not ok: raise SystemExit(f'Archive sidecar mismatch: {path}')
            info['sha256']=sha256_file(path); candidates.append(info)
    grouped=defaultdict(list)
    for item in candidates: grouped[item['package_id']].append(item)
    selected=[]; duplicates=[]
    for pid in REQUIRED_IDS:
        values=grouped.get(pid,[])
        if not values: raise SystemExit(f'Missing required prior package: {pid}')
        if len(values)>1:
            preferred=[]
            for v in values:
                expected = LEGACY_ARCHIVES.get(v['package_number'],(None,None))[0] if v['package_number']<=4 else None
                score=(1 if expected and v['path'].name==expected else 0, v['modern'], v['package_version'], v['path'].name)
                preferred.append((score,v))
            preferred.sort(reverse=True,key=lambda x:x[0]); chosen=preferred[0][1]
            for _,v in preferred[1:]: duplicates.append({'package_id':pid,'selected':str(chosen['path']),'excluded':str(v['path']),'reason':'duplicate_or_superseded_archive'})
        else: chosen=values[0]
        selected.append(chosen)
    return selected, duplicates


def map_status(row: dict, default_original='derived_synthesis') -> dict:
    review=row.get('review_state') or row.get('review_status') or 'candidate_not_yet_human_reviewed'
    return {
        'review_state': review,
        'native_review_state': row.get('native_review_state') or review,
        'original_review_state': row.get('original_review_state') or row.get('review_status') or default_original,
        'original_verification_status': row.get('original_verification_status') or row.get('verification_status') or 'legacy_source_links_preserved',
        'logic_verification_status': row.get('logic_verification_status') or row.get('verification_status') or 'candidate_unverified_on_installed_logic',
        'runtime_eligibility': row.get('runtime_eligibility') or 'retrieval_candidate',
    }


def migrate_modern(info: dict) -> dict:
    def enrich(
        rows: list[dict],
        default_original: str,
        runtime_default: str,
        logic_default: str = 'candidate_unverified_on_installed_logic',
    ) -> list[dict]:
        output=[]
        for original in rows:
            row=dict(original)
            mapped=map_status(row, default_original)
            mapped['runtime_eligibility']=row.get('runtime_eligibility') or runtime_default
            mapped['logic_verification_status']=row.get('logic_verification_status') or row.get('verification_status') or logic_default
            for key,value in mapped.items():
                if row.get(key) in {None, ''}:
                    row[key]=value
            output.append(row)
        return output

    with zipfile.ZipFile(info['path']) as z:
        r=info['root']
        utterances=zjsonl(z,r,['corpus/user_utterances.jsonl'])
        for row in utterances:
            if row.get('variant_type') in {'exact_reference','test_exact_reference'}:
                row['runtime_eligibility']='test_only'
        return {
            'meta': info,
            'canonical': enrich(zjsonl(z,r,['corpus/canonical_qa.jsonl']), 'derived_synthesis', 'retrieval_candidate'),
            'utterances': enrich(utterances, 'synthetic_language_variant', 'retrieval_candidate'),
            'scenarios': enrich(zjsonl(z,r,['corpus/multiturn_scenarios.jsonl']), 'synthetic_multiturn_evaluation', 'test_only'),
            'evaluations': enrich(zjsonl(z,r,['corpus/retrieval_evaluations.jsonl']), 'synthetic_retrieval_evaluation', 'test_only'),
            'contradictions': enrich(zjsonl(z,r,['corpus/contradictions.jsonl']), 'derived_disagreement_synthesis', 'retrieval_candidate'),
            'myths': enrich(zjsonl(z,r,['corpus/myths_and_antipatterns.jsonl']), 'derived_myth_correction', 'retrieval_candidate'),
            'claims': enrich(zjsonl(z,r,['knowledge_candidates/claims.jsonl']), 'derived_claim_candidate', 'retrieval_candidate'),
            'strategies': enrich(zjsonl(z,r,['knowledge_candidates/strategies.jsonl']), 'derived_strategy_candidate', 'retrieval_candidate'),
            'procedures': enrich(zjsonl(z,r,['knowledge_candidates/logic_procedures.jsonl']), 'candidate_logic_procedure', 'excluded_from_runtime'),
            'sources': enrich(zjsonl(z,r,['sources/source_registry.jsonl']), 'registered_source_metadata', 'source_reference_only', 'not_applicable_to_source'),
            'provenance': enrich(zjsonl(z,r,['sources/provenance_manifest.jsonl']), 'source_provenance_record', 'source_reference_only', 'not_applicable_to_source'),
            'legacy_mappings': [],
        }


def migrate_legacy(info: dict) -> dict:
    n=info['package_number']; pid=info['package_id']; ns=f'pkg{n:03d}'
    with zipfile.ZipFile(info['path']) as z:
        r=info['root']
        old_sources=zjsonl(z,r,['research/source_registry.jsonl'])
        source_map={}
        sources=[]
        for i,old in enumerate(old_sources,1):
            oid=old.get('id') or old.get('source_id') or f'legacy-source-{i}'
            nid=f'{ns}.source.{i:06d}'; source_map[oid]=nid
            sources.append({
                'id':nid,'package_id':pid,'title':old.get('title') or oid,
                'publisher_or_community':old.get('publisher') or old.get('publisher_or_community') or 'Legacy source',
                'canonical_url':old.get('canonical_url') or old.get('url') or '',
                'evidence_class':old.get('evidence_class') or old.get('source_type') or 'legacy_source',
                'access_mode':old.get('access_mode') or old.get('access_status') or 'legacy_registered_source',
                'content_stored':False,'model_facing_username':False,
                'review_state':old.get('review_status') or 'candidate_reviewed_documentary',
                'native_review_state':old.get('review_status') or 'candidate_reviewed_documentary',
                'original_review_state':old.get('review_status') or 'legacy_source_registry',
                'original_verification_status':'legacy_source_metadata_preserved',
                'logic_verification_status':'not_applicable_to_source','runtime_eligibility':'source_reference_only',
                'version_scope':old.get('logic_version_scope') or 'legacy package source scope',
                'tags':old.get('topics') or [],'limitations':old.get('limitations') or [],'original_id':oid,
            })
        old_canonical=zjsonl(z,r,['corpus/canonical_qa.jsonl'])
        old_canonical=sorted(old_canonical,key=lambda x:str(x.get('id','')))
        qa_map={}
        canonical=[]; legacy_mappings=[]
        for i,old in enumerate(old_canonical,1):
            oid=str(old.get('id') or f'legacy-qa-{i}'); nid=f'{ns}.qa.{i:06d}'; qa_map[oid]=nid
            s=map_status(old)
            source_ids=[source_map.get(x,x) for x in old.get('source_ids',[]) if x]
            hypotheses=[]
            for h in old.get('candidate_hypotheses') or []:
                if isinstance(h,dict): hypotheses.append(h.get('label') or h.get('mechanism') or json.dumps(h,ensure_ascii=False))
                else: hypotheses.append(str(h))
            clarification=old.get('clarification_questions') or []
            steps=old.get('logic_pro_steps') or []
            if isinstance(steps,str): steps=[steps]
            logic_guidance={
                'logic_version_scope':old.get('logic_version_scope') or 'Legacy package; verify on installed Logic',
                'status':'candidate_unverified_on_installed_logic','location':old.get('logic_location') or '',
                'steps':steps,'starting_points':old.get('starting_points') or [],
                'listen_for':old.get('what_to_listen_for') or [],'stop_rule':old.get('stop_rule') or old.get('stop_conditions') or '',
                'undo':old.get('undo_or_reset') or old.get('undo') or '',
            }
            record={
                'id':nid,'original_id':oid,'package_id':pid,'package_number':n,
                'domain':old.get('domain') or 'unknown','subdomain':old.get('subcategory') or old.get('category') or 'legacy',
                'topic':old.get('category') or old.get('subcategory') or old.get('title') or 'legacy',
                'title':old.get('title') or oid,
                'canonical_question':old.get('canonical_question') or old.get('canonical_user_question') or old.get('title') or oid,
                'problem_summary':old.get('problem_summary') or old.get('canonical_user_question') or old.get('title') or oid,
                'user_intent':'production_tutor_question',
                'direct_answer':old.get('direct_answer') or old.get('rationale') or old.get('recommended_first_experiment') or '',
                'key_distinction':'; '.join(old.get('do_not_assume') or []) if isinstance(old.get('do_not_assume'),list) else str(old.get('do_not_assume') or ''),
                'clarification_questions':clarification,
                'competing_hypotheses':hypotheses,
                'evidence_needed':['Current source/object scope','Relevant before/after or solo/mix comparison','User-confirmed outcome'],
                'recommended_first_experiment':old.get('recommended_first_experiment') or '',
                'logic_guidance':logic_guidance,
                'tradeoffs':old.get('tradeoffs') or old.get('tradeoffs_and_risks') or [],
                'non_processing_possibilities':old.get('non_processing_possibilities') or old.get('non_dsp_possibilities') or [],
                'teaching_principle':old.get('teaching_principle') or '',
                'retrieval_tags':list(dict.fromkeys((old.get('tags') or [])+(old.get('user_language_aliases') or [])))[:64],
                'source_ids':source_ids,'evidence_class':old.get('evidence_class') or 'derived_synthesis',
                'variant_kind':'legacy_migrated','limitations':old.get('limitations') or old.get('do_not_assume') or [],
                **s,
            }
            canonical.append(record)
            legacy_mappings.append({'package_id':pid,'record_type':'canonical_qa','original_id':oid,'new_id':nid})
        utterances=[]
        canonical_domain_by_id={q['id']: q.get('domain','unknown') for q in canonical}
        old_utter=zjsonl(z,r,['corpus/user_utterances.jsonl'])
        for i,old in enumerate(old_utter,1):
            oid=str(old.get('id') or old.get('utterance_id') or f'legacy-utterance-{i}')
            oldqa=str(old.get('canonical_qa_id') or old.get('canonical_id') or '')
            if oldqa not in qa_map: continue
            s=map_status(old,'synthetic_language_variant')
            utterances.append({'id':f'{ns}.utterance.{i:07d}','original_id':oid,'canonical_qa_id':qa_map[oldqa],
                'package_id':pid,'domain':old.get('domain') or canonical_domain_by_id.get(qa_map[oldqa],'unknown'),
                'subdomain':old.get('category') or 'legacy','text':old.get('text',''),'variant_type':old.get('variant_type') or old.get('difficulty') or 'natural',
                'retrieval_tags':tokens(old.get('text',''))[:32],'synthetic':old.get('synthetic',True),**s})
            legacy_mappings.append({'package_id':pid,'record_type':'user_utterance','original_id':oid,'new_id':f'{ns}.utterance.{i:07d}'})
        scenarios=[]
        for i,old in enumerate(zjsonl(z,r,['corpus/multiturn_scenarios.jsonl']),1):
            oldqa=str(old.get('canonical_qa_id') or old.get('canonical_id') or '')
            if oldqa not in qa_map: continue
            turns=old.get('messages') or old.get('turns') or []
            msgs=[]
            for t in turns:
                msgs.append({'role':t.get('role','user').replace('assistant_expected_behavior','assistant_expected'),'text':t.get('text') or t.get('content') or t.get('behavior') or ''})
            scenarios.append({'id':f'{ns}.scenario.{i:07d}','canonical_qa_id':qa_map[oldqa],'package_id':pid,
                'domain':old.get('domain') or 'unknown','subdomain':old.get('category') or 'legacy','scenario_type':old.get('scenario_type') or old.get('branch_kind') or 'legacy',
                'messages':msgs,'expected_behaviors':old.get('expected_behaviors') or old.get('required_behaviors') or old.get('evaluation_criteria') or [],
                'forbidden_behaviors':old.get('forbidden_behaviors') or [],**map_status(old,'synthetic_multiturn_evaluation'),'runtime_eligibility':'test_only'})
        evaluations=[]
        old_evals=zjsonl(z,r,['corpus/retrieval_evaluations.jsonl','corpus/retrieval_evaluation.jsonl','corpus/evaluation_cases.jsonl'])
        for i,old in enumerate(old_evals,1):
            oldqa=str(old.get('canonical_qa_id') or old.get('canonical_id') or ((old.get('expected_canonical_ids') or [''])[0]))
            if oldqa not in qa_map: continue
            evaluations.append({'id':f'{ns}.eval.legacy.{i:07d}','canonical_qa_id':qa_map[oldqa],'package_id':pid,
                'evaluation_type':'diagnostic_semantic_only','retrieval_classification':'diagnostic_semantic_only','diagnostic_only':True,
                'query':old.get('query') or old.get('prompt') or '', 'expected_canonical_ids':[qa_map[oldqa]],
                'forbidden_canonical_ids':[],'expected_response_properties':old.get('expected_criteria') or [],
                'retrieval_expectation':'diagnostic_only',**map_status(old,'legacy_evaluation'),'runtime_eligibility':'test_only'})
        # Generate one deterministic exact test alias for each legacy canonical record.
        for i,qa in enumerate(canonical,1):
            evaluations.append({'id':f'{ns}.eval.exact.{i:06d}','canonical_qa_id':qa['id'],'package_id':pid,
                'evaluation_type':'exact_unique','retrieval_classification':'exact_unique','diagnostic_only':False,
                'query':EXACT_PREFIX.format(number=n,index=i),'expected_canonical_ids':[qa['id']],
                'forbidden_canonical_ids':[],'expected_response_properties':['unique identity retrieval only'],
                'retrieval_expectation':'expected_top_1',**map_status(qa),'runtime_eligibility':'test_only'})
        def migrate_simple(rows,candidates,kind):
            out=[]
            for i,old in enumerate(rows,1):
                oldqa=str(old.get('canonical_qa_id') or old.get('canonical_id') or old.get('canonicalQAID') or '')
                qa=qa_map.get(oldqa)
                if kind in {'claims','strategies','procedures','provenance'} and not qa: continue
                nid=f'{ns}.{kind[:-1] if kind.endswith("s") else kind}.{i:06d}'
                s=map_status(old)
                if kind=='claims':
                    out.append({'id':nid,'canonical_qa_id':qa,'package_id':pid,'claim_text':old.get('claim_text') or old.get('claimText') or '',
                        'conditions':old.get('conditions') or [],'limitations':old.get('limitations') or [],'source_ids':[source_map.get(x,x) for x in old.get('source_ids',old.get('sourceIDs',[]))],
                        'evidence_class':old.get('evidence_class') or 'derived_synthesis',**s})
                elif kind=='strategies':
                    out.append({'id':nid,'canonical_qa_id':qa,'package_id':pid,'label':old.get('label') or 'Legacy candidate strategy',
                        'recommended_first_experiment':old.get('recommended_first_experiment') or old.get('recommendedFirstExperiment') or '',
                        'what_to_listen_for':old.get('what_to_listen_for') or old.get('expectedAudibleConsequences') or [],
                        'stop_rule':old.get('stop_rule') or old.get('stoppingRules') or '', 'undo':old.get('undo') or '',
                        'tradeoffs':old.get('tradeoffs') or [],'source_ids':[source_map.get(x,x) for x in old.get('source_ids',old.get('sourceIDs',[]))],**s})
                elif kind=='procedures':
                    out.append({'id':nid,'canonical_qa_id':qa,'package_id':pid,'title':old.get('title') or old.get('label') or 'Legacy candidate procedure',
                        'logic_version_scope':old.get('logic_version_scope') or old.get('logicVersionScope') or 'Legacy package; reverify installed Logic',
                        'location':old.get('location') or '', 'steps':old.get('steps') or [], 'listen_for':old.get('listen_for') or old.get('listenFor') or '',
                        'risk':old.get('risk') or '', 'undo':old.get('undo') or '', 'verification_status':'candidate_unverified_on_installed_logic',
                        'execution_authority':False,'source_ids':[source_map.get(x,x) for x in old.get('source_ids',old.get('sourceIDs',[]))],**s,'runtime_eligibility':'excluded_from_runtime'})
            return out
        claims=migrate_simple(zjsonl(z,r,['knowledge_candidates/claims.jsonl','integration/tracksmith_claim_candidates.jsonl']),'claims','claims')
        strategies=migrate_simple(zjsonl(z,r,['knowledge_candidates/strategies.jsonl','integration/tracksmith_strategy_candidates.jsonl']),'strategies','strategies')
        procedures=migrate_simple(zjsonl(z,r,['knowledge_candidates/logic_procedures.jsonl','integration/logic_procedure_candidates.jsonl']),'procedures','procedures')
        contradictions=[]
        for i,old in enumerate(zjsonl(z,r,['corpus/contradictions.jsonl','research/contradictions.jsonl']),1):
            contradictions.append({'id':f'{ns}.contradiction.{i:05d}','package_id':pid,'topic':old.get('topic') or old.get('title') or 'Legacy disagreement',
                'position_a':old.get('position_a') or old.get('positionA') or '', 'position_b':old.get('position_b') or old.get('positionB') or '',
                'what_decides':old.get('what_decides') or old.get('whatDeterminesWhichApplies') or '',
                'source_ids':[source_map.get(x,x) for x in old.get('source_ids',[])],**map_status(old,'legacy_disagreement')})
        myths=[]
        for i,old in enumerate(zjsonl(z,r,['corpus/myths_and_antipatterns.jsonl','research/myths_and_antipatterns.jsonl']),1):
            myths.append({'id':f'{ns}.myth.{i:05d}','package_id':pid,'myth':old.get('myth') or old.get('claim') or '',
                'correction':old.get('correction') or old.get('response') or '', 'safer_principle':old.get('safer_principle') or old.get('principle') or '',
                'source_ids':[source_map.get(x,x) for x in old.get('source_ids',[])],**map_status(old,'legacy_myth_correction')})
        provenance=[]
        for i,qa in enumerate(canonical,1):
            provenance.append({'id':f'{ns}.provenance.{i:06d}','canonical_qa_id':qa['id'],'package_id':pid,
                'source_ids':qa['source_ids'],'transformation':'Legacy record migrated into stable schema; original ID and statuses preserved.',
                **map_status(qa),'runtime_eligibility':'source_reference_only'})
        return {'meta':info,'canonical':canonical,'utterances':utterances,'scenarios':scenarios,'evaluations':evaluations,
            'contradictions':contradictions,'myths':myths,'claims':claims,'strategies':strategies,'procedures':procedures,
            'sources':sources,'provenance':provenance,'legacy_mappings':legacy_mappings}


def migrate_archive(info: dict) -> dict:
    return migrate_modern(info) if info['modern'] else migrate_legacy(info)


def unique_ids(groups: dict[str,list[dict]]) -> list[dict]:
    seen={}; collisions=[]
    for name,rows in groups.items():
        for row in rows:
            rid=row.get('id')
            if not rid: continue
            if rid in seen: collisions.append({'id':rid,'first':seen[rid],'second':name})
            else: seen[rid]=name
    return collisions


def runtime_projection(canonical:list[dict], utterances:list[dict]) -> tuple[list[dict],list[dict]]:
    canon=[]
    for r in canonical:
        item={k:r[k] for k in ALLOWED_CANONICAL_RUNTIME if k in r}
        canon.append(item)
    utt=[]
    for r in utterances:
        if r.get('runtime_eligibility') in {'test_only','excluded_from_runtime'}: continue
        if r.get('variant_type') in {'exact_reference','test_exact_reference'}: continue
        item={k:r[k] for k in ALLOWED_UTTERANCE_RUNTIME if k in r}
        utt.append(item)
    return canon,utt


def recursive_runtime_check(obj:Any,path='$') -> list[str]:
    errors=[]
    if isinstance(obj,dict):
        for k,v in obj.items():
            if k in FORBIDDEN_RUNTIME_KEYS: errors.append(f'{path}.{k}')
            errors.extend(recursive_runtime_check(v,f'{path}.{k}'))
    elif isinstance(obj,list):
        for i,v in enumerate(obj): errors.extend(recursive_runtime_check(v,f'{path}[{i}]'))
    elif isinstance(obj,str):
        low=obj.lower()
        if 'corpus.sqlite' in low or low.endswith('.sqlite') or 'expected_top_1' in low: errors.append(path)
    return errors


def build_unified_database(out:Path, packages:list[dict], datasets:list[dict]) -> dict:
    out.parent.mkdir(parents=True,exist_ok=True)
    if out.exists(): out.unlink()
    c=sqlite3.connect(out); cur=c.cursor()
    cur.executescript('''
    PRAGMA journal_mode=DELETE; PRAGMA foreign_keys=ON;
    CREATE TABLE packages(package_id TEXT PRIMARY KEY, package_number INTEGER, package_version TEXT, archive_sha256 TEXT, manifest_json TEXT);
    CREATE TABLE canonical_qa(id TEXT PRIMARY KEY, package_id TEXT, domain TEXT, subdomain TEXT, title TEXT, canonical_question TEXT, direct_answer TEXT, experiment TEXT, review_state TEXT, evidence_class TEXT, record_json TEXT);
    CREATE TABLE user_utterances(id TEXT PRIMARY KEY, canonical_qa_id TEXT, package_id TEXT, text TEXT, variant_type TEXT, runtime_eligible INTEGER, record_json TEXT);
    CREATE TABLE multiturn_scenarios(id TEXT PRIMARY KEY, canonical_qa_id TEXT, package_id TEXT, scenario_type TEXT, record_json TEXT);
    CREATE TABLE retrieval_evaluations(id TEXT PRIMARY KEY, canonical_qa_id TEXT, package_id TEXT, evaluation_type TEXT, query TEXT, diagnostic_only INTEGER, record_json TEXT);
    CREATE TABLE contradictions(id TEXT PRIMARY KEY, package_id TEXT, topic TEXT, position_a TEXT, position_b TEXT, record_json TEXT);
    CREATE TABLE myths_and_antipatterns(id TEXT PRIMARY KEY, package_id TEXT, myth TEXT, correction TEXT, record_json TEXT);
    CREATE TABLE claim_candidates(id TEXT PRIMARY KEY, canonical_qa_id TEXT, package_id TEXT, claim_text TEXT, review_state TEXT, record_json TEXT);
    CREATE TABLE strategy_candidates(id TEXT PRIMARY KEY, canonical_qa_id TEXT, package_id TEXT, label TEXT, review_state TEXT, record_json TEXT);
    CREATE TABLE logic_procedure_candidates(id TEXT PRIMARY KEY, canonical_qa_id TEXT, package_id TEXT, title TEXT, verification_status TEXT, review_state TEXT, record_json TEXT);
    CREATE TABLE sources(id TEXT PRIMARY KEY, package_id TEXT, title TEXT, publisher_or_community TEXT, canonical_url TEXT, evidence_class TEXT, access_mode TEXT, record_json TEXT);
    CREATE TABLE provenance(id TEXT PRIMARY KEY, canonical_qa_id TEXT, package_id TEXT, source_ids_json TEXT, record_json TEXT);
    CREATE TABLE legacy_id_mappings(package_id TEXT, record_type TEXT, original_id TEXT, new_id TEXT, PRIMARY KEY(package_id,record_type,original_id));
    CREATE TABLE exact_fixture_aliases(normalized_alias TEXT PRIMARY KEY, canonical_qa_id TEXT UNIQUE, package_id TEXT, query TEXT);
    CREATE TABLE alias_registry(normalized_alias TEXT, canonical_qa_id TEXT, package_id TEXT, alias_type TEXT, runtime_eligible INTEGER, PRIMARY KEY(normalized_alias,canonical_qa_id,alias_type));
    CREATE TABLE alias_collisions(normalized_alias TEXT PRIMARY KEY, canonical_ids_json TEXT, packages_json TEXT, collision_type TEXT);
    CREATE TABLE audio_datasets(id TEXT PRIMARY KEY, title TEXT, access_mode TEXT, profile_json TEXT, record_json TEXT);
    CREATE TABLE retrieval_receipts(id TEXT PRIMARY KEY, created_at TEXT, query_hash TEXT, result_ids_json TEXT, policy_json TEXT);
    CREATE VIRTUAL TABLE canonical_qa_fts USING fts5(id UNINDEXED, title, canonical_question, direct_answer, experiment, tags, utterances, tokenize='unicode61 remove_diacritics 2');
    CREATE INDEX idx_canonical_package ON canonical_qa(package_id); CREATE INDEX idx_canonical_domain ON canonical_qa(domain); CREATE INDEX idx_utterance_qa ON user_utterances(canonical_qa_id);
    ''')
    allsets={k:[] for k in ['canonical','utterances','scenarios','evaluations','contradictions','myths','claims','strategies','procedures','sources','provenance','legacy_mappings']}
    for p in packages:
        meta=p['meta']; cur.execute('INSERT INTO packages VALUES (?,?,?,?,?)',(meta['package_id'],meta['package_number'],meta['package_version'],meta['sha256'],json.dumps(meta['manifest'],sort_keys=True,ensure_ascii=False)))
        for k in allsets: allsets[k].extend(p.get(k,[]))
    utter_by=defaultdict(list)
    for u in allsets['utterances']:
        if u.get('runtime_eligibility') not in {'test_only','excluded_from_runtime'} and u.get('variant_type') not in {'exact_reference','test_exact_reference'}:
            utter_by[u['canonical_qa_id']].append(text_value(u.get('text','')))
    cur.executemany('INSERT INTO canonical_qa VALUES (?,?,?,?,?,?,?,?,?,?,?)',[(r['id'],text_value(r.get('package_id','')),text_value(r.get('domain','')),text_value(r.get('subdomain','')),text_value(r.get('title','')),text_value(r.get('canonical_question','')),text_value(r.get('direct_answer','')),text_value(r.get('recommended_first_experiment','')),text_value(r.get('review_state','')),text_value(r.get('evidence_class','')),json.dumps(r,sort_keys=True,ensure_ascii=False)) for r in allsets['canonical']])
    cur.executemany('INSERT INTO canonical_qa_fts VALUES (?,?,?,?,?,?,?)',[(r['id'],text_value(r.get('title','')),text_value(r.get('canonical_question','')),text_value(r.get('direct_answer','')),text_value(r.get('recommended_first_experiment','')),' '.join(text_value(x) for x in r.get('retrieval_tags',[])),'\n'.join(utter_by.get(r['id'],[])[:64])) for r in allsets['canonical']])
    mappings=[
      ('utterances','user_utterances',lambda r:(r['id'],r['canonical_qa_id'],r.get('package_id',''),text_value(r.get('text','')),text_value(r.get('variant_type','')),0 if r.get('runtime_eligibility') in {'test_only','excluded_from_runtime'} else 1,json.dumps(r,sort_keys=True,ensure_ascii=False))),
      ('scenarios','multiturn_scenarios',lambda r:(r['id'],r['canonical_qa_id'],r.get('package_id',''),text_value(r.get('scenario_type','')),json.dumps(r,sort_keys=True,ensure_ascii=False))),
      ('evaluations','retrieval_evaluations',lambda r:(r['id'],r['canonical_qa_id'],r.get('package_id',''),text_value(r.get('evaluation_type','')),text_value(r.get('query','')),1 if r.get('diagnostic_only') else 0,json.dumps(r,sort_keys=True,ensure_ascii=False))),
      ('contradictions','contradictions',lambda r:(r['id'],r.get('package_id',''),text_value(r.get('topic','')),text_value(r.get('position_a','')),text_value(r.get('position_b','')),json.dumps(r,sort_keys=True,ensure_ascii=False))),
      ('myths','myths_and_antipatterns',lambda r:(r['id'],r.get('package_id',''),text_value(r.get('myth','')),text_value(r.get('correction','')),json.dumps(r,sort_keys=True,ensure_ascii=False))),
      ('claims','claim_candidates',lambda r:(r['id'],r['canonical_qa_id'],r.get('package_id',''),text_value(r.get('claim_text','')),text_value(r.get('review_state','')),json.dumps(r,sort_keys=True,ensure_ascii=False))),
      ('strategies','strategy_candidates',lambda r:(r['id'],r['canonical_qa_id'],r.get('package_id',''),text_value(r.get('label','')),text_value(r.get('review_state','')),json.dumps(r,sort_keys=True,ensure_ascii=False))),
      ('procedures','logic_procedure_candidates',lambda r:(r['id'],r['canonical_qa_id'],r.get('package_id',''),text_value(r.get('title','')),text_value(r.get('verification_status') or r.get('logic_verification_status','')),text_value(r.get('review_state','')),json.dumps(r,sort_keys=True,ensure_ascii=False))),
      ('sources','sources',lambda r:(r['id'],r.get('package_id',''),text_value(r.get('title','')),text_value(r.get('publisher_or_community','')),text_value(r.get('canonical_url','')),text_value(r.get('evidence_class','')),text_value(r.get('access_mode','')),json.dumps(r,sort_keys=True,ensure_ascii=False))),
      ('provenance','provenance',lambda r:(r['id'],r['canonical_qa_id'],r.get('package_id',''),json.dumps(r.get('source_ids',[])),json.dumps(r,sort_keys=True,ensure_ascii=False))),
      ('legacy_mappings','legacy_id_mappings',lambda r:(r['package_id'],r['record_type'],r['original_id'],r['new_id'])),
    ]
    for key,table,fn in mappings:
        rows=allsets[key]
        if rows:
            first=fn(rows[0])
            placeholders=','.join('?' for _ in first)
            cur.execute(f"INSERT INTO {table} VALUES ({placeholders})", first)
            batch=[]
            for r in rows[1:]:
                batch.append(fn(r))
                if len(batch)>=1000:
                    cur.executemany(f"INSERT INTO {table} VALUES ({placeholders})", batch)
                    batch.clear()
            if batch:
                cur.executemany(f"INSERT INTO {table} VALUES ({placeholders})", batch)
    # Test-only exact aliases and runtime natural alias registry.
    exact=[]
    for p in packages:
        n=p['meta']['package_number']
        for i,r in enumerate(sorted(p['canonical'],key=lambda x:x['id']),1):
            q=EXACT_PREFIX.format(number=n,index=i); exact.append((norm(q),r['id'],r.get('package_id',''),q))
    cur.executemany('INSERT INTO exact_fixture_aliases VALUES (?,?,?,?)',exact)
    alias_to_ids=defaultdict(set); alias_rows=[]
    for r in allsets['canonical']:
        a=norm(text_value(r.get('canonical_question','')))
        if a: alias_to_ids[a].add(r['id']); alias_rows.append((a,r['id'],r.get('package_id',''),'canonical_question',1))
    for u in allsets['utterances']:
        if u.get('runtime_eligibility') in {'test_only','excluded_from_runtime'}: continue
        if u.get('variant_type') in {'exact_reference','test_exact_reference'}: continue
        a=norm(text_value(u.get('text','')))
        if a: alias_to_ids[a].add(u['canonical_qa_id']); alias_rows.append((a,u['canonical_qa_id'],u.get('package_id',''),'utterance',1))
    # Deduplicate rows.
    seen=set(); dedup=[]
    for x in alias_rows:
        key=(x[0],x[1],x[3])
        if key not in seen: seen.add(key); dedup.append(x)
    cur.executemany('INSERT OR IGNORE INTO alias_registry VALUES (?,?,?,?,?)',dedup)
    collisions=[]
    id_to_pkg={r['id']:r.get('package_id','') for r in allsets['canonical']}
    for a,ids in alias_to_ids.items():
        if len(ids)>1:
            packages_set=sorted({id_to_pkg.get(i,'') for i in ids}); ctype='cross_package' if len(packages_set)>1 else 'within_package'
            collisions.append((a,json.dumps(sorted(ids)),json.dumps(packages_set),ctype))
    cur.executemany('INSERT INTO alias_collisions VALUES (?,?,?,?)',collisions)
    for ds in datasets:
        profiles=(ds.get('download') or {}).get('profiles',[])
        cur.execute('INSERT INTO audio_datasets VALUES (?,?,?,?,?)',(ds['id'],ds['title'],ds['access_mode'],json.dumps(profiles),json.dumps(ds,sort_keys=True,ensure_ascii=False)))
    c.commit(); status=cur.execute('PRAGMA integrity_check').fetchone()[0]
    table_counts={t:cur.execute(f'SELECT COUNT(*) FROM {t}').fetchone()[0] for t in ['packages','canonical_qa','user_utterances','multiturn_scenarios','retrieval_evaluations','contradictions','myths_and_antipatterns','claim_candidates','strategy_candidates','logic_procedure_candidates','sources','provenance','legacy_id_mappings','exact_fixture_aliases','alias_collisions','audio_datasets']}
    c.close()
    if status!='ok': raise SystemExit(f'Unified database integrity failed: {status}')
    return {'table_counts':table_counts,'alias_collision_count':len(collisions),'exact_fixture_count':len(exact),'allsets':allsets}


def build_unified_bundle(prior:Path,out:Path) -> dict:
    selected,duplicates=discover_packages(prior)
    packages=[]
    for info in selected:
        info=dict(info); info['sha256']=sha256_file(info['path']); packages.append(migrate_archive(info))
    groups={k:[] for k in ['canonical','utterances','scenarios','evaluations','contradictions','myths','claims','strategies','procedures','sources','provenance']}
    for p in packages:
        for k in groups: groups[k].extend(p[k])
    collisions=unique_ids(groups)
    if collisions: raise SystemExit(f'Unresolved ID collisions after migration: {collisions[:5]}')
    out.mkdir(parents=True,exist_ok=True)
    db=out/'unified_corpus.sqlite'; result=build_unified_database(db,packages,AUDIO['datasets'])
    canon_rt,utt_rt=runtime_projection(groups['canonical'],groups['utterances'])
    errors=[]
    for i,r in enumerate(canon_rt): errors.extend(recursive_runtime_check(r,f'canonical[{i}]'))
    for i,r in enumerate(utt_rt): errors.extend(recursive_runtime_check(r,f'utterance[{i}]'))
    if errors: raise SystemExit(f'Runtime projection purity failure: {errors[:20]}')
    write_jsonl(out/'unified_canonical.runtime.jsonl',canon_rt)
    write_jsonl(out/'unified_utterances.runtime.jsonl',utt_rt)
    mappings=[]
    for p in packages: mappings.extend(p.get('legacy_mappings',[]))
    write_jsonl(out/'legacy_id_mappings.jsonl',mappings)
    c=sqlite3.connect(db)
    collision_rows=c.execute('SELECT normalized_alias,canonical_ids_json,packages_json,collision_type FROM alias_collisions').fetchall()
    collision_types=dict(c.execute('SELECT collision_type,COUNT(*) FROM alias_collisions GROUP BY collision_type').fetchall())
    c.close()
    collision_records=[{'normalized_alias':a,'canonical_ids':json.loads(ids),'package_ids':json.loads(pkgs),'collision_type':t,'resolution':'diagnostic_only_require_context'} for a,ids,pkgs,t in collision_rows]
    write_jsonl(out/'alias_collisions.jsonl',collision_records)
    quality_report={
        'package_count':len(packages),
        'canonical_count':len(groups['canonical']),
        'runtime_canonical_count':len(canon_rt),
        'runtime_utterance_count':len(utt_rt),
        'exact_fixture_count':result['exact_fixture_count'],
        'exact_fixture_policy':'test_only_unique_identity_lookup',
        'alias_collision_count':len(collision_rows),
        'alias_collision_types':collision_types,
        'collision_resolution':'diagnostic_only_require_context',
        'retrieval_budget':{'canonical_max':4,'per_package_max':2,'per_domain_max':2,'contradiction_max':1,'myth_max':2},
        'representative_collision_examples':collision_records[:25],
        'runtime_forbidden_material':['candidate_procedures','Logic_navigation','evaluation_answers','multi_turn_scenarios','SQLite_paths','exact_test_aliases','execution_authority'],
    }
    atomic_json(out/'retrieval_quality_report.json',quality_report)
    summary={'packages':[{'package_id':p['meta']['package_id'],'package_number':p['meta']['package_number'],'package_version':p['meta']['package_version'],'archive':p['meta']['path'].name,'sha256':p['meta']['sha256']} for p in packages],
        'duplicates_excluded':duplicates,'counts':{k:len(v) for k,v in groups.items()},'runtime_counts':{'canonical':len(canon_rt),'utterances':len(utt_rt)},
        'database':result['table_counts'],'alias_collision_count':result['alias_collision_count'],'exact_fixture_count':result['exact_fixture_count'],
        'retrieval_budget':{'canonical_max':4,'per_package_max':2,'per_domain_max':2,'contradiction_max':1,'myth_max':2}}
    atomic_json(out/'unified_manifest.json',summary)
    return summary


def safe_extract(path:Path,dest:Path):
    dest.mkdir(parents=True,exist_ok=True)
    if zipfile.is_zipfile(path):
        with zipfile.ZipFile(path) as z:
            for m in z.infolist():
                target=(dest/m.filename).resolve()
                if dest.resolve() not in target.parents and target!=dest.resolve(): raise SystemExit('Unsafe ZIP path')
            z.extractall(dest)
    elif tarfile.is_tarfile(path):
        with tarfile.open(path) as t:
            for m in t.getmembers():
                target=(dest/m.name).resolve()
                if dest.resolve() not in target.parents and target!=dest.resolve(): raise SystemExit('Unsafe TAR path')
            t.extractall(dest,filter='data')


def download_url(url:str,path:Path):
    path.parent.mkdir(parents=True,exist_ok=True)
    temp=path.with_suffix(path.suffix+'.partial')
    req=urllib.request.Request(url,headers={'User-Agent':'TrackSmith-Audio-Evaluation-Asset-Manager/1.0'})
    with urllib.request.urlopen(req,timeout=60) as src, temp.open('wb') as dst:
        shutil.copyfileobj(src,dst,length=1024*1024)
    os.replace(temp,path)


def zenodo_file(record_id:int,filename:str)->str:
    with urllib.request.urlopen(f'https://zenodo.org/api/records/{record_id}',timeout=60) as r:
        obj=json.load(r)
    for f in obj.get('files',[]):
        if f.get('key')==filename or f.get('filename')==filename:
            return (f.get('links') or {}).get('content') or (f.get('links') or {}).get('self')
    raise RuntimeError(f'File {filename!r} not found in Zenodo record {record_id}')


def prepare_audio_assets(root:Path,profile:str,max_bytes:int,allow_large:bool,plan_only:bool=False)->dict:
    profile_ids=set(AUDIO['profiles'][profile]['dataset_ids'])
    selected=[d for d in AUDIO['datasets'] if d['id'] in profile_ids]
    root.mkdir(parents=True,exist_ok=True)
    plan=[]; downloaded=[]; skipped=[]; pending=[]
    known=sum((d.get('download') or {}).get('size_bytes') or 0 for d in selected)
    free=shutil.disk_usage(root).free
    if known>max_bytes and not allow_large:
        # Keep working: select assets in declared order until cap is reached.
        total=0; kept=[]
        for d in selected:
            size=(d.get('download') or {}).get('size_bytes') or 0
            if total+size<=max_bytes: kept.append(d); total+=size
            else: skipped.append({'id':d['id'],'reason':'download_cap_deferred'})
        selected=kept; known=total
    if known and free < int(known*1.5):
        # Do not ask; keep the smallest assets that fit and report the rest.
        total=0; kept=[]
        for d in sorted(selected,key=lambda x:(x.get('download') or {}).get('size_bytes') or 0):
            size=(d.get('download') or {}).get('size_bytes') or 0
            if free-total>int(size*1.5): kept.append(d); total+=size
            else: skipped.append({'id':d['id'],'reason':'insufficient_space_deferred'})
        selected=kept
    for d in selected:
        spec=d.get('download') or {}; kind=spec.get('kind')
        if kind=='request_required': pending.append({'id':d['id'],'url':d['canonical_url'],'reason':'official access approval required'}); continue
        if kind in {'zenodo_record_manual_selection','landing_page_recipe'}: skipped.append({'id':d['id'],'reason':'manual_selection_or_large_dataset_deferred'}); continue
        filename=spec.get('filename')
        if not filename: skipped.append({'id':d['id'],'reason':'no_automatic_filename'}); continue
        path=root/filename
        entry={'id':d['id'],'filename':filename,'size_bytes':spec.get('size_bytes',0),'status':'planned'}; plan.append(entry)
        if plan_only: continue
        if not path.exists():
            url=spec.get('url') if kind=='direct' else zenodo_file(int(spec['record_id']),filename)
            download_url(url,path)
        ctype=spec.get('checksum_type'); expected=spec.get('checksum')
        if ctype in {'sha256','md5'} and expected:
            actual=checksum_file(path,ctype)
            if actual.lower()!=expected.lower(): raise SystemExit(f'Checksum mismatch for {path.name}: {actual}')
        if spec.get('extract'):
            dest=root/(filename+'.extracted')
            if not dest.exists(): safe_extract(path,dest)
        downloaded.append({'id':d['id'],'filename':filename,'sha256':sha256_file(path),'size_bytes':path.stat().st_size})
    result={'profile':profile,'root':str(root),'planned':plan,'downloaded':downloaded,'skipped':skipped,'pending_access':pending}
    atomic_json(root/'audio_asset_manifest.json',result); atomic_json(root/'pending_access_requests.json',pending)
    return result


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--target',required=True); ap.add_argument('--prior-packages',required=True)
    ap.add_argument('--dry-run',action='store_true'); ap.add_argument('--force',action='store_true')
    ap.add_argument('--prepare-audio-assets',action='store_true'); ap.add_argument('--audio-profile',choices=['smoke','standard','full','request_required'],default='smoke')
    ap.add_argument('--audio-root'); ap.add_argument('--max-download-gb',type=float,default=8.0); ap.add_argument('--allow-large-downloads',action='store_true'); ap.add_argument('--plan-audio-only',action='store_true'); ap.add_argument('--prebuilt-unified')
    args=ap.parse_args()
    target=Path(args.target).expanduser().resolve(); prior=Path(args.prior_packages).expanduser().resolve()
    if not (target/'.git').exists(): raise SystemExit('Target must be a Git checkout.')
    with tempfile.TemporaryDirectory(prefix='tracksmith-pkg016-') as td:
        if args.prebuilt_unified:
            temp=Path(args.prebuilt_unified).expanduser().resolve()
            manifest_path=temp/'unified_manifest.json'
            if not manifest_path.exists(): raise SystemExit('Prebuilt unified bundle is missing unified_manifest.json')
            summary=json.loads(manifest_path.read_text(encoding='utf-8'))
        else:
            temp=Path(td)/'unified'; summary=build_unified_bundle(prior,temp)
        dest=target/'research/community_knowledge/packages'/M['package_id']
        unified=target/'research/community_knowledge/unified'; runtime=target/'research/community_knowledge/runtime'
        plan={'status':'dry_run' if args.dry_run else 'planned','package_id':M['package_id'],'destination':str(dest),'unified_directory':str(unified),
            'runtime_directory':str(runtime),'summary':summary,'audio_profile':args.audio_profile if args.prepare_audio_assets else None}
        print(json.dumps(plan,indent=2,sort_keys=True))
        if args.dry_run:
            if args.prepare_audio_assets:
                audio_root=Path(args.audio_root).expanduser() if args.audio_root else target/'research/community_knowledge/audio_assets'
                print(json.dumps(prepare_audio_assets(audio_root,args.audio_profile,int(args.max_download_gb*1e9),args.allow_large_downloads,plan_only=True),indent=2))
            return
        if dest.exists() and not args.force: raise SystemExit('Package 016 destination exists; use --force for intentional replacement.')
        dest.parent.mkdir(parents=True,exist_ok=True); staging=dest.parent/f'.{M["package_id"]}.importing-{os.getpid()}'
        if staging.exists(): shutil.rmtree(staging)
        shutil.copytree(ROOT,staging,ignore=shutil.ignore_patterns('__pycache__','*.zip','.DS_Store'))
        if dest.exists(): shutil.rmtree(dest)
        os.replace(staging,dest)
        if unified.exists(): shutil.rmtree(unified)
        shutil.copytree(temp,unified)
        runtime.mkdir(parents=True,exist_ok=True)
        shutil.copy2(temp/'unified_canonical.runtime.jsonl',runtime/'unified_canonical.runtime.jsonl')
        shutil.copy2(temp/'unified_utterances.runtime.jsonl',runtime/'unified_utterances.runtime.jsonl')
        regpath=target/'research/community_knowledge/package_registry.json'
        reg=json.loads(regpath.read_text()) if regpath.exists() else {'contract':'tracksmith-community-package-registry','version':'2.0','packages':[]}
        selected_ids={p['package_id'] for p in summary['packages']} | {M['package_id']}
        entries=[x for x in reg.get('packages',[]) if x.get('package_id') not in selected_ids]
        for prior_package in summary['packages']:
            entries.append({
                'package_id':prior_package['package_id'],
                'package_number':prior_package['package_number'],
                'package_version':prior_package.get('package_version','1.0.0'),
                'archive_name':prior_package['archive'],
                'archive_sha256':prior_package['sha256'],
                'normalized_by':M['package_id'],
                'runtime_projection':str((runtime/'unified_canonical.runtime.jsonl').relative_to(target)),
                'status':'normalized_and_registered',
            })
        entries.append({'package_id':M['package_id'],'package_number':16,'package_version':'1.0.0','contract_version':'1.0','path':str(dest.relative_to(target)),
            'unified_manifest':str((unified/'unified_manifest.json').relative_to(target)),'runtime_canonical':str((runtime/'unified_canonical.runtime.jsonl').relative_to(target)),
            'runtime_utterances':str((runtime/'unified_utterances.runtime.jsonl').relative_to(target)),'depends_on':M['depends_on'],'status':'integration_framework_active'})
        reg['packages']=sorted(entries,key=lambda x:(x.get('package_number',999),x.get('package_id',''))); atomic_json(regpath,reg)
        audio_result=None
        if args.prepare_audio_assets:
            audio_root=Path(args.audio_root).expanduser() if args.audio_root else target/'research/community_knowledge/audio_assets'
            audio_result=prepare_audio_assets(audio_root,args.audio_profile,int(args.max_download_gb*1e9),args.allow_large_downloads,plan_only=args.plan_audio_only)
        report={**plan,'status':'staged','audio_result':audio_result}; atomic_json(target/f'research/community_knowledge/import_report_{M["package_id"]}.json',report)
        print('Staged Package 016, unified database/runtime projections, registry and optional audio assets.')

if __name__=='__main__': main()
