#!/usr/bin/env python3
"""Fail-closed, evaluation-only Package 017 importer.

It never runs supplied tools and never writes a runtime resource.  The copied
package stays beneath research/tutor_quality where evaluators may read expected
answers; generation, app resources, and provider requests are checked separately.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import shutil
import sqlite3
import stat
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
PID = "tracksmith-corpus-017-golden-tutor-conversations-level-adaptation"
ARCHIVE_SHA256 = "a9f11b1d5962dfb50e21ed6588b107a81f50a317ab68f7a8981729b3492165e8"
SIDECAR_SHA256 = "0a23ff0887ac67b04c2b35646949d65922488f2e8d5aae12e6651e1c8161d392"
QUALITY = ROOT / "research/tutor_quality"
DESTINATION = QUALITY / "packages" / PID
REGISTRY = QUALITY / "package_registry.json"
REPORT = QUALITY / "import_report_package017.json"
CONTRACT = QUALITY / "experience_level_contract.json"
BASELINE = QUALITY / "preservation_baseline_p001_p016.json"


def die(message: str) -> None:
    raise SystemExit("P17_IMPORT_ERROR: " + message)


def sha(path: pathlib.Path) -> str:
    if path.is_symlink() or not path.is_file():
        die("unsafe or missing file " + str(path))
    return hashlib.sha256(path.read_bytes()).hexdigest()


def files(root: pathlib.Path) -> dict[str, pathlib.Path]:
    if root.is_symlink() or not root.is_dir():
        die("unsafe root " + str(root))
    output: dict[str, pathlib.Path] = {}
    for base, directories, names in os.walk(root, followlinks=False):
        base_path = pathlib.Path(base)
        for name in directories + names:
            path = base_path / name
            mode = path.lstat().st_mode
            if path.is_symlink() or (name in directories and not stat.S_ISDIR(mode)) or (name in names and not stat.S_ISREG(mode)):
                die("non-regular package path " + str(path))
        for name in names:
            path = base_path / name
            output[path.relative_to(root).as_posix()] = path
    return output


def digest(root: pathlib.Path) -> dict[str, object]:
    entries = files(root)
    value = hashlib.sha256()
    for relative, path in sorted(entries.items()):
        value.update(b"FILE\0" + relative.encode() + b"\0" + path.read_bytes())
    return {"fileCount": len(entries), "sha256": value.hexdigest()}


def json_value(path: pathlib.Path) -> object:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as error:
        die("invalid JSON " + str(path) + ": " + str(error))


def write_new(path: pathlib.Path, value: object) -> None:
    if path.exists() or path.is_symlink():
        die("refuses to replace " + str(path))
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=path.name + ".", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump(value, stream, indent=2, sort_keys=True)
            stream.write("\n")
            stream.flush(); os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary): os.unlink(temporary)


def allowlist(incoming: pathlib.Path) -> dict[str, str]:
    sums = incoming / "PACKAGE_SHA256SUMS.txt"
    expected: dict[str, str] = {"PACKAGE_SHA256SUMS.txt": sha(sums)}
    for line in sums.read_text(encoding="utf-8").splitlines():
        pair = line.split("  ", 1)
        if len(pair) != 2 or len(pair[0]) != 64:
            die("checksum line shape")
        relative = pathlib.PurePosixPath(pair[1])
        if relative.is_absolute() or ".." in relative.parts or pair[1] in expected:
            die("unsafe checksum path")
        expected[pair[1]] = pair[0]
    actual = files(incoming)
    if len(expected) != 47 or set(expected) != set(actual):
        die("expected exact 47-file tree")
    for relative, expected_sha in expected.items():
        if sha(actual[relative]) != expected_sha: die("checksum drift " + relative)
    return expected


def predecessors() -> dict[str, str]:
    path = ROOT / "research/community_knowledge/package_registry.json"
    registry = json_value(path)
    if not isinstance(registry, dict) or not isinstance(registry.get("packages"), list): die("legacy registry shape")
    rows = [row for row in registry["packages"] if isinstance(row, dict) and 1 <= row.get("package_number", 0) <= 16]
    if [row["package_number"] for row in rows] != list(range(1, 17)): die("P001-P016 prerequisite sequence")
    legacy = {1: "tracksmith-corpus-001-vocal-quantization", 2: "tracksmith-corpus-002-level-balancing-eq", 3: "tracksmith-corpus-003-compression-arrangement-frequency-allocation", 4: "tracksmith-corpus-004-reverb-delay"}
    return {legacy.get(int(row["package_number"]), str(row["package_id"])): str(row["package_id"]) for row in rows}


def runtime_leak_check() -> None:
    # Evaluation material itself is deliberately excluded from this scan.
    targets = [
        ROOT / "research/community_knowledge/runtime_projection/p16",
        ROOT / "packages/ProductionTutor/Sources/ProductionTutor/GeneralTutorKnowledge.generated.swift",
        ROOT / "packages/ProductionTutor/Sources/ProductionTutor/CommunityCandidateCorpus.generated.swift",
        ROOT / "packages/TutorConversation/Sources/TutorConversation",
        ROOT / "apps/CompanionMacApp",
    ]
    forbidden = ("pkg017", "golden_tutor", "expected_assistant", "expected_response", "corpus.sqlite")
    hits: list[str] = []
    for target in targets:
        if not target.exists(): continue
        for _, path in files(target).items() if target.is_dir() else [(target.name, target)]:
            if path.suffix not in {".swift", ".json", ".jsonl", ".sqlite"}: continue
            try: text = path.read_text(encoding="utf-8", errors="ignore").lower()
            except OSError: continue
            if any(token in text for token in forbidden): hits.append(str(path.relative_to(ROOT)))
    if hits: die("evaluation data leaked to runtime " + ",".join(hits[:4]))


def validate(incoming: pathlib.Path, archive: pathlib.Path, sidecar: pathlib.Path) -> dict[str, object]:
    if sha(archive) != ARCHIVE_SHA256: die("archive SHA256 pin drift")
    if sha(sidecar) != SIDECAR_SHA256 or sidecar.read_text(encoding="utf-8").strip() != ARCHIVE_SHA256 + "  " + archive.name:
        die("archive sidecar pin/text drift")
    allowed = allowlist(incoming)
    manifest = json_value(incoming / "package_manifest.json")
    integration = json_value(incoming / "integration/integration_manifest.json")
    if not isinstance(manifest, dict) or manifest.get("package_id") != PID or manifest.get("package_type") != "evaluation_framework": die("identity/type")
    if not isinstance(integration, dict): die("integration manifest")
    counts = integration.get("counts", {})
    expected_counts = {"canonical_qa": 180, "multiturn_scenarios": 540, "retrieval_evaluations": 900}
    if {key: counts.get(key) for key in expected_counts} != expected_counts: die("180/540/900 accounting")
    if integration.get("evaluation_isolation", {}).get("runtime_record_count") != 0: die("runtime count")
    levels = integration.get("experience_level_contract", {}).get("levels", {})
    if set(levels) != {"noob", "amateur", "pro"}: die("level triplets")
    connection = sqlite3.connect(f"file:{incoming / 'database/corpus.sqlite'}?mode=ro", uri=True)
    try:
        if connection.execute("PRAGMA integrity_check").fetchone()[0] != "ok": die("SQLite integrity")
    finally: connection.close()
    resolved = predecessors()
    runtime_leak_check()
    return {"packageID": PID, "archiveSHA256": ARCHIVE_SHA256, "sidecarSHA256": SIDECAR_SHA256, "tree": digest(incoming), "packageFiles": len(allowed),
            "canonical": 180, "scenarios": 540, "retrievalEvaluations": 900, "runtimeRecordCount": 0,
            "levels": sorted(levels), "dependencyResolution": resolved, "metadataRepairCount": 0,
            "evaluationOnly": True, "suppliedImporterExecuted": False}


def baseline() -> dict[str, object]:
    registry = ROOT / "research/community_knowledge/package_registry.json"
    resources = ROOT / "research/community_knowledge/runtime_projection/p16"
    return {"legacyRegistrySHA256": sha(registry), "runtimeResourceTree": digest(resources), "predecessors": predecessors()}


def stage(incoming: pathlib.Path, evidence: dict[str, object], dry_run: bool) -> None:
    planned = [DESTINATION, REGISTRY, REPORT, CONTRACT, BASELINE]
    if dry_run:
        print("P17_DRY_RUN_OK writes=0 additivePaths=" + json.dumps([str(p.relative_to(ROOT)) for p in planned], separators=(",", ":"))); return
    if any(path.exists() or path.is_symlink() for path in planned): die("P17 artifacts already exist")
    before = baseline(); allowed = allowlist(incoming)
    DESTINATION.parent.mkdir(parents=True, exist_ok=True)
    temporary = pathlib.Path(tempfile.mkdtemp(prefix=".p17-stage-", dir=DESTINATION.parent))
    try:
        for relative, expected_sha in allowed.items():
            source, target = incoming / relative, temporary / relative
            target.parent.mkdir(parents=True, exist_ok=True); shutil.copyfile(source, target, follow_symlinks=False)
            if sha(target) != expected_sha: die("copy drift " + relative)
        if digest(temporary) != digest(incoming): die("staged tree digest")
        os.replace(temporary, DESTINATION)
        write_new(CONTRACT, {"schemaVersion": "1.0", "packageID": PID, "persistentDefault": "amateur", "visibleLabels": {"noob":"Noob", "amateur":"Amateur", "pro":"Pro"}, "explicitSelectionOnly": True, "temporaryOverridesPersist": False, "runtimeRecordCount": 0})
        write_new(BASELINE, before)
        write_new(REGISTRY, {"schemaVersion": "1.0", "packages": [{"packageID": PID, "packageNumber": 17, "packageType": "evaluation_framework", "path": str(DESTINATION.relative_to(ROOT)), "runtimeResource": "none", "dependencies": evidence["dependencyResolution"]}]})
        write_new(REPORT, {"status": "staged", **evidence, "preservationBaseline": str(BASELINE.relative_to(ROOT)), "runtimeLeakScan": "passed"})
    except BaseException:
        # Never alter P001-P016. A partial P17 stage is retained for forensic inspection.
        if temporary.exists(): shutil.rmtree(temporary)
        raise
    if baseline() != before: die("P001-P016 preservation drift")
    print("P17_STAGE_OK files=47 prerequisites=16 canonical=180 scenarios=540 retrieval=900 runtime=0")


def check(incoming: pathlib.Path, archive: pathlib.Path, sidecar: pathlib.Path) -> None:
    evidence = validate(incoming, archive, sidecar)
    if not all(path.is_file() and not path.is_symlink() for path in (REGISTRY, REPORT, CONTRACT, BASELINE)): die("missing stage artifacts")
    if digest(DESTINATION) != digest(incoming): die("destination tree drift")
    if json_value(BASELINE) != baseline(): die("P001-P016 preservation drift")
    print("P17_CHECK_OK prerequisites=16 canonical=180 scenarios=540 retrieval=900 runtime=0 metadataRepairCount=0")


def self_test(incoming: pathlib.Path, archive: pathlib.Path, sidecar: pathlib.Path) -> None:
    """Exercise the checksum rejection path without touching the trusted input."""
    validate(incoming, archive, sidecar)
    with tempfile.TemporaryDirectory(prefix="p17-corruption-") as directory:
        copied = pathlib.Path(directory) / "package"
        shutil.copytree(incoming, copied, symlinks=True)
        target = copied / "README.md"
        target.write_bytes(target.read_bytes() + b"\ncorruption-test\n")
        try:
            allowlist(copied)
        except SystemExit as error:
            if not str(error).startswith("P17_IMPORT_ERROR:"):
                raise
        else:
            die("corruption self-test unexpectedly accepted modified bytes")
    print("P17_SELF_TEST_OK corruptionsRejected=1 runtime=0")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--incoming", type=pathlib.Path, required=True); parser.add_argument("--archive", type=pathlib.Path, required=True); parser.add_argument("--sidecar", type=pathlib.Path, required=True)
    action = parser.add_mutually_exclusive_group(required=True); action.add_argument("--preflight", action="store_true"); action.add_argument("--dry-run", action="store_true"); action.add_argument("--stage", action="store_true"); action.add_argument("--check", action="store_true"); action.add_argument("--self-test", action="store_true")
    args = parser.parse_args(); incoming, archive, sidecar = args.incoming.resolve(), args.archive.resolve(), args.sidecar.resolve(); evidence = validate(incoming, archive, sidecar)
    if args.preflight: print("P17_PREFLIGHT_OK files=47 canonical=180 scenarios=540 retrieval=900 levels=amateur,noob,pro runtime=0 sqlite=ok")
    elif args.dry_run: stage(incoming, evidence, True)
    elif args.stage: stage(incoming, evidence, False)
    elif args.check: check(incoming, archive, sidecar)
    else: self_test(incoming, archive, sidecar)


if __name__ == "__main__": main()
