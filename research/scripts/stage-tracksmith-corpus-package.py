#!/usr/bin/env python3
"""Repository-owned, no-follow CAS staging for stable-contract corpus packages."""
from __future__ import annotations
import argparse, hashlib, json, os, pathlib, shutil, stat, subprocess, sys, tempfile
import community_corpus_import as trusted
ROOT=pathlib.Path(__file__).resolve().parents[2]; COMMUNITY=ROOT/"research/community_knowledge"
PACKAGE019_FORCE_SEMANTICS_ATTESTATIONS={
    "tracksmith-corpus-005-automation": ROOT/"research/tutor_quality/package019_package005_force_semantics_attestation.json",
    "tracksmith-corpus-006-saturation-transient-shaping": ROOT/"research/tutor_quality/package019_package006_force_semantics_attestation.json",
}
EXCLUDED_ROOTS={".git",".build","DerivedData","__pycache__",".claude",".codex"}
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def fail(message): raise SystemExit("CAS_STAGE_ERROR: "+message)
def walk_fail(error): fail("inventory walk error: "+str(error))
def inventory(root):
    root=pathlib.Path(root); records={}
    if root.is_symlink() or not root.is_dir(): fail("unsafe inventory root")
    for base,directories,names in os.walk(root,followlinks=False,onerror=walk_fail):
        base_path=pathlib.Path(base); relbase=base_path.relative_to(root)
        if relbase.parts and relbase.parts[0] in EXCLUDED_ROOTS: directories[:]=[]; continue
        mode=base_path.lstat().st_mode
        if stat.S_ISLNK(mode) or not stat.S_ISDIR(mode): fail("unsafe directory: "+relbase.as_posix())
        records[relbase.as_posix()]={"type":"directory","mode":stat.S_IMODE(mode)}
        for name in directories+names:
            path=base_path/name; rel=path.relative_to(root)
            if rel.parts and rel.parts[0] in EXCLUDED_ROOTS: continue
            value=path.lstat().st_mode
            if stat.S_ISDIR(value): continue
            if stat.S_ISREG(value): records[rel.as_posix()]={"type":"file","mode":stat.S_IMODE(value),"sha256":sha(path)}
            elif stat.S_ISLNK(value): fail("unsafe symlink: "+rel.as_posix())
            else: fail("unsafe special entry: "+rel.as_posix())
    return records
def tree(root):
    values=inventory(root); h=hashlib.sha256()
    for relative,value in sorted(values.items()):
        if value["type"]=="file": h.update(b"FILE\0"+relative.encode()+b"\0"+(pathlib.Path(root)/relative).read_bytes())
    return {"fileCount":sum(x["type"]=="file" for x in values.values()),"sha256":h.hexdigest()}
def atomic_json(path,value):
    data=json.dumps(value,indent=2,sort_keys=True,ensure_ascii=False)+"\n"; path.parent.mkdir(parents=True,exist_ok=True)
    fd,tmp=tempfile.mkstemp(prefix=path.name+".",suffix=".tmp",dir=path.parent)
    try:
        with os.fdopen(fd,"w",encoding="utf-8") as out: out.write(data); out.flush(); os.fsync(out.fileno())
        os.replace(tmp,path)
    finally:
        if os.path.exists(tmp): os.unlink(tmp)
def package(external):
    inv=tree(external); manifest=external/"package_manifest.json"
    if manifest.is_symlink() or not manifest.is_file(): fail("manifest missing or unsafe")
    value=json.loads(manifest.read_text()); pid=value.get("package_id"); number=value.get("package_number")
    if value.get("package_contract")!="tracksmith-corpus-package" or value.get("contract_version")!="1.0" or not isinstance(pid,str) or not isinstance(number,int): fail("stable-contract identity drift")
    return value,pid,number,inv
def audit(external):
    manifest,pid,number,expected=package(external); destination=COMMUNITY/"packages"/pid; registry_path=COMMUNITY/"package_registry.json"; report=COMMUNITY/("import_report_"+pid+".json"); dep=COMMUNITY/"dependency_maps"/(pid+".json"); mapping=COMMUNITY/"disagreement_maps"/(pid+".json")
    if tree(destination)!=expected: fail("staged tree byte/inventory drift")
    entries=json.loads(registry_path.read_text())["packages"]
    if sum(x.get("package_id")==pid for x in entries)!=1 or next(x for x in entries if x.get("package_id")==pid).get("package_number")!=number or [x.get("package_number") for x in entries if isinstance(x.get("package_number"),int)] != sorted(x.get("package_number") for x in entries if isinstance(x.get("package_number"),int)): fail("registry row/order drift")
    if any(x.is_symlink() or not x.is_file() for x in (report,dep,mapping)): fail("evidence path drift")
    expected_map=trusted.STABLE_CONTRACT_SPECS.get(pid,{}).get("disagreementSHA256")
    if expected_map is not None and sha(mapping)!=expected_map: fail("disagreement-map pin drift")
    report_value=json.loads(report.read_text())
    force_semantics=report_value.get("force_semantics")
    if force_semantics is None and pid in PACKAGE019_FORCE_SEMANTICS_ATTESTATIONS:
        # These immutable historical reports predate this explicit field.
        # Read a separately pinned portable projection instead of mutating a
        # report or treating omission as a semantic opt-in.
        attestation_path=PACKAGE019_FORCE_SEMANTICS_ATTESTATIONS[pid]
        if not attestation_path.is_file() or attestation_path.is_symlink(): fail("portable force-semantics attestation missing for "+pid)
        attestation=json.loads(attestation_path.read_text())
        if attestation.get("package_id") != pid or attestation.get("historical_report_sha256") != sha(report) or attestation.get("portable_projection",{}).get("force_semantics") is not False:
            fail("portable force-semantics attestation drift for "+pid)
        force_semantics=False
    if force_semantics is not False: fail("force semantics detected")
    if trusted.STABLE_CONTRACT_SPECS.get(pid,{}).get("integrationManifestReconciliation"):
        try: reconciliation=trusted.integration_contract_reconciliation(pid,destination)
        except (OSError, ValueError, json.JSONDecodeError) as error: fail(str(error))
        row=next(x for x in entries if x.get("package_id")==pid)
        if trusted.STABLE_CONTRACT_SPECS[pid].get("metadataRepair"):
            # Staging records the immutable incoming declaration before the
            # shipping resources exist.  Once they do, the importer upgrades
            # both records together to the capability-declared pins.
            try: reconciliation=trusted.metadata_repair_reconciliation(pid)
            except ValueError as error:
                if "requires shipping resources" not in str(error): fail(str(error))
        if row.get("runtime_contract_reconciliation") != reconciliation or report_value.get("runtime_contract_reconciliation") != reconciliation:
            fail("staged integration contract reconciliation drift")
    print("CAS_STAGED_AUDIT_OK package=%s files=%d registryEntries=%d"%(pid,expected["fileCount"],len(entries)))
def main():
    ap=argparse.ArgumentParser(); ap.add_argument("--external",type=pathlib.Path,required=True); ap.add_argument("--dependency-map",type=pathlib.Path); ap.add_argument("--archive",type=pathlib.Path); ap.add_argument("--audit-staged",action="store_true"); a=ap.parse_args(); external=a.external.expanduser()
    if external.is_symlink() or not external.is_dir(): fail("external root missing or unsafe")
    if a.audit_staged: audit(external); return
    if a.dependency_map is None: fail("--dependency-map is required")
    manifest,pid,number,external_tree=package(external); registry_path=COMMUNITY/"package_registry.json"; destination=COMMUNITY/"packages"/pid; report=COMMUNITY/("import_report_"+pid+".json"); dep=COMMUNITY/"dependency_maps"/(pid+".json"); mapping=COMMUNITY/"disagreement_maps"/(pid+".json"); standards=COMMUNITY/"standards_maps"/(pid+".json")
    supplied=a.dependency_map.expanduser()
    if supplied.is_symlink() or not supplied.is_file() or any(x.is_symlink() for x in (registry_path,destination,report,dep,mapping)): fail("unsafe target or evidence path")
    if destination.exists() or report.exists(): fail("refuses an existing destination/report")
    # Strict preflight consumes a reviewed repository-owned map before staging.
    # Reuse only that exact same byte path; never overwrite a separate map.
    reuse_dependency_map=dep.exists()
    if reuse_dependency_map and (dep.resolve()!=supplied.resolve() or sha(dep)!=sha(supplied)): fail("refuses a distinct or drifting dependency map")
    if not mapping.is_file(): fail("requires a checked-in explicit disagreement map")
    if pid == "tracksmith-corpus-009-gain-staging-bus-processing-loudness" and not standards.is_file(): fail("requires a checked-in reviewed standards map")
    if trusted.STABLE_CONTRACT_SPECS.get(pid,{}).get("archiveRequired") and (a.archive is None or a.archive.is_symlink() or not a.archive.is_file()): fail("stable staging requires an immutable archive path")
    subprocess.run([
        sys.executable, str(ROOT / "research/scripts/preflight-tracksmith-corpus-package.py"),
        "--incoming", str(external), "--dependency-map", str(supplied),
        "--disagreement-map", str(mapping), *( ["--standards-map", str(standards)] if standards.is_file() else [] ), *( ["--archive", str(a.archive)] if a.archive is not None else [] ), "--strict-stage",
    ], check=True)
    registry=json.loads(registry_path.read_text()); before=inventory(COMMUNITY); entries=registry["packages"]
    if any(x.get("package_id")==pid for x in entries): fail("registry already contains package")
    tmp=destination.parent/("."+pid+".staging-"+str(os.getpid())); created=[]
    try:
        shutil.copytree(external,tmp,symlinks=True); inventory(tmp)
        if tree(tmp)!=external_tree: fail("temporary copy inventory drift")
        os.replace(tmp,destination); created.append(destination)
        if not reuse_dependency_map:
            dep.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(supplied,dep); created.append(dep)
        dependency_resolution=json.loads(supplied.read_text())
        entry={"package_id":pid,"package_number":number,"package_version":manifest["package_version"],"contract_version":manifest["contract_version"],"path":str(destination.relative_to(ROOT)),"review_state":manifest["review_state"],"logic_procedure_status":manifest["logic_procedure_status"],"depends_on":manifest["depends_on"],"dependency_resolution":dependency_resolution,"package_manifest_sha256":sha(destination/"package_manifest.json")}
        if trusted.STABLE_CONTRACT_SPECS.get(pid,{}).get("integrationManifestReconciliation"): entry["runtime_contract_reconciliation"]=trusted.integration_contract_reconciliation(pid,destination)
        entries.append(entry)
        atomic_json(registry_path,{**registry,"packages":entries}); created.append(registry_path)
        report_value={"status":"staged","package_id":pid,"package_version":manifest["package_version"],"record_counts":manifest["record_counts"],"package_manifest_sha256":sha(destination/"package_manifest.json"),"dependency_resolution":dependency_resolution,"staged_tree":external_tree,"staging_authority":"repository_owned_no_follow_copy","incoming_importer_executed":False,"force_semantics":False}
        if trusted.STABLE_CONTRACT_SPECS.get(pid,{}).get("integrationManifestReconciliation"): report_value["runtime_contract_reconciliation"]=trusted.integration_contract_reconciliation(pid,destination)
        atomic_json(report,report_value); created.append(report)
        after=inventory(COMMUNITY); changed={x for x in set(before)|set(after) if before.get(x)!=after.get(x)}; allowed={str(x.relative_to(COMMUNITY)) for x in [destination,*destination.rglob("*"),registry_path,report] + ([] if reuse_dependency_map else [dep])}
        if changed!=allowed: fail("per-path delta drift: "+", ".join(sorted(changed^allowed)[:8]))
    except BaseException:
        if tmp.exists(): shutil.rmtree(tmp)
        for target in reversed(created):
            if target == registry_path: atomic_json(registry_path,registry)
            elif target.exists(): shutil.rmtree(target) if target.is_dir() else target.unlink()
        raise
    print("CAS_STAGE_OK package=%s stagedFiles=%d stagedSHA256=%s"%(pid,external_tree["fileCount"],external_tree["sha256"]))
if __name__=="__main__": main()
