#!/usr/bin/env python3
"""Capture or verify the exact P001-P010 state protected by P011 work."""
from __future__ import annotations
import argparse, hashlib, json, pathlib
import community_corpus_import as trusted

ROOT=pathlib.Path(__file__).resolve().parents[2]; COMMUNITY=ROOT/"research/community_knowledge"; KNOWLEDGE=ROOT/"research/knowledge"
RES=ROOT/"research/community_knowledge/runtime_projection/p16"; EVAL=ROOT/"tools/TutorConversationTests/Resources"
DESCRIPTOR=ROOT/"packages/ProductionTutor/Sources/ProductionTutor/CommunityCandidateCorpus.generated.swift"
BASELINE=COMMUNITY/"preservation_baselines/tracksmith-corpus-011-smart-tempo-bpm-detection-tempo-mapping.json"; P10="tracksmith-corpus-010-flex-time-manual-timing"
def digest(value): return hashlib.sha256(value).hexdigest()
def compact(value): return digest(json.dumps(value,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode())
def tree(path):
    files,value=trusted.preservation_tree(path)
    return {"files":files,"tree":value}
def package_path(pid): return COMMUNITY/"packages"/pid if pid.startswith("tracksmith-corpus") else KNOWLEDGE/pid
def state():
    registry=json.loads((COMMUNITY/"package_registry.json").read_text()); protected=[x for x in registry["packages"] if x.get("package_number",0)<=10]
    if [x.get("package_number") for x in protected] != list(range(1,11)): raise SystemExit("P11_BASELINE_ERROR: package sequence through P10 drift")
    sources=json.loads((KNOWLEDGE/"general-tutor-source-registry.json").read_text())["sources"]; queue=json.loads((KNOWLEDGE/"general-tutor-review-queue.json").read_text())["candidates"]
    lines=DESCRIPTOR.read_text().splitlines(keepends=True); packages={}
    for entry in protected:
        pid=entry["package_id"]; path=package_path(pid); manifest=path/("package_manifest.json" if (path/"package_manifest.json").exists() else "manifest.json")
        line=next((x for x in lines if f'packageID: "{pid}"' in x),None)
        if line is None: raise SystemExit("P11_BASELINE_ERROR: descriptor missing "+pid)
        packages[pid]={**tree(path),"manifest":digest(manifest.read_bytes()),"runtime":digest((RES/(pid+".json")).read_bytes()),"evaluation":digest((EVAL/(pid+"-evaluation.json")).read_bytes()),"sourceProjection":compact([x for x in sources if x.get("candidateCorpus")==pid]),"queueProjection":compact([x for x in queue if x.get("candidateCorpus")==pid]),"descriptorLine":digest(line.rstrip(",\n").encode())}
    report=json.loads((COMMUNITY/("import_report_"+P10+".json")).read_text()); p10row=next(x for x in registry["packages"] if x.get("package_id")==P10); reconciliation=trusted.p10_runtime_contract_reconciliation(COMMUNITY/"packages"/P10)
    if p10row.get("runtime_contract_reconciliation")!=reconciliation or report.get("runtime_contract_reconciliation")!=reconciliation: raise SystemExit("P11_BASELINE_ERROR: P10 reconciliation drift")
    if packages[P10]["runtime"]!="da8c0cb4cf44b192fde0cb64c6063ed81d0106395bff9f7dfb6487bb9b3cf49b" or packages[P10]["evaluation"]!="b20b83fd55352d67449e17578b9fb22b8760ce69976667f0a9ae19037d81541c": raise SystemExit("P11_BASELINE_ERROR: P10 resource pin drift")
    return {"schemaVersion":"1.0","preservesThroughPackage":10,"registryProjection":compact(protected),"packages":packages,"p10RuntimeSHA256":packages[P10]["runtime"],"p10EvaluationSHA256":packages[P10]["evaluation"],"p10Reconciliation":reconciliation}
def main():
    check=argparse.ArgumentParser(); check.add_argument("--check",action="store_true"); a=check.parse_args(); observed=state()
    if a.check:
        if not BASELINE.exists() or not trusted.preservation_baseline_matches(json.loads(BASELINE.read_text()),observed): raise SystemExit("P11_BASELINE_CHECK_FAILED: Package 001-010 bytes/state drift")
        print("P11_PRESERVATION_BASELINE_OK packages=10 p10Runtime=true p10Evaluation=true")
    else:
        BASELINE.parent.mkdir(parents=True,exist_ok=True); existing=json.loads(BASELINE.read_text()) if BASELINE.exists() else {}; BASELINE.write_text(json.dumps(trusted.preservation_capture_document(existing,observed),indent=2,sort_keys=True)+"\n"); print("P11_PRESERVATION_BASELINE_CAPTURED packages=10 p10Runtime=true p10Evaluation=true")
if __name__=="__main__": main()
