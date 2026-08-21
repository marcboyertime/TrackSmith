#!/usr/bin/env python3
"""Capture/verify the immutable P001-P011 state before P012 projections run."""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re

import community_corpus_import as trusted

ROOT = pathlib.Path(__file__).resolve().parents[2]
COMMUNITY = ROOT / "research/community_knowledge"
KNOWLEDGE = ROOT / "research/knowledge"
RESOURCES = ROOT / "research/community_knowledge/runtime_projection/p16"
EVALUATIONS = ROOT / "tools/TutorConversationTests/Resources"
DESCRIPTOR = ROOT / "packages/ProductionTutor/Sources/ProductionTutor/CommunityCandidateCorpus.generated.swift"
GENERATED = ROOT / "packages/ProductionTutor/Sources/ProductionTutor/GeneralTutorKnowledge.generated.swift"
BASELINE = COMMUNITY / "preservation_baselines/tracksmith-corpus-012-recording-latency-monitoring-comping-punch.json"
P10 = "tracksmith-corpus-010-flex-time-manual-timing"
P11 = "tracksmith-corpus-011-smart-tempo-bpm-detection-tempo-mapping"


def digest(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def compact(value: object) -> str:
    return digest(json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode())


def tree(path: pathlib.Path) -> dict[str, object]:
    value = hashlib.sha256()
    files = sorted(item for item in path.rglob("*") if item.is_file())
    for item in files:
        value.update(b"FILE\0" + item.relative_to(path).as_posix().encode() + b"\0" + item.read_bytes())
    return {"files": len(files), "tree": value.hexdigest()}


def package_path(pid: str) -> pathlib.Path:
    return COMMUNITY / "packages" / pid if pid.startswith("tracksmith-corpus") else KNOWLEDGE / pid


def source_only_projection() -> str:
    text = GENERATED.read_text(encoding="utf-8")
    start, end = text.find('#"""'), text.rfind('"""#')
    if start < 0 or end < 0:
        raise SystemExit("P12_BASELINE_ERROR: generated source payload unreadable")
    payload = json.loads(text[start + 4:end])
    # A successor may add source-only provenance.  P12 preserves the prior
    # projection, so remove P12 and all later package source namespaces.
    def pre_p12_source(row: dict) -> bool:
        match = re.match(r"^pkg(\d{3})\.", str(row.get("id", "")))
        return match is None or int(match.group(1)) < 12
    payload["sources"] = [row for row in payload.get("sources", []) if pre_p12_source(row)]
    return compact(payload)


def state() -> dict[str, object]:
    registry = json.loads((COMMUNITY / "package_registry.json").read_text(encoding="utf-8"))
    protected = [row for row in registry["packages"] if row.get("package_number", 0) <= 11]
    if [row.get("package_number") for row in protected] != list(range(1, 12)):
        raise SystemExit("P12_BASELINE_ERROR: package sequence through P11 drift")
    sources = json.loads((KNOWLEDGE / "general-tutor-source-registry.json").read_text(encoding="utf-8"))["sources"]
    queue = json.loads((KNOWLEDGE / "general-tutor-review-queue.json").read_text(encoding="utf-8"))["candidates"]
    lines = DESCRIPTOR.read_text(encoding="utf-8").splitlines(keepends=True)
    packages = {}
    for entry in protected:
        pid = entry["package_id"]
        path = package_path(pid)
        manifest = path / ("package_manifest.json" if (path / "package_manifest.json").exists() else "manifest.json")
        line = next((value for value in lines if f'packageID: "{pid}"' in value), None)
        if line is None:
            raise SystemExit("P12_BASELINE_ERROR: descriptor missing " + pid)
        packages[pid] = {
            **tree(path), "manifest": digest(manifest.read_bytes()),
            "runtime": digest((RESOURCES / f"{pid}.json").read_bytes()),
            "evaluation": digest((EVALUATIONS / f"{pid}-evaluation.json").read_bytes()),
            "sourceProjection": compact([row for row in sources if row.get("candidateCorpus") == pid]),
            "queueProjection": compact([row for row in queue if row.get("candidateCorpus") == pid]),
            "descriptorLine": digest(line.rstrip(",\n").encode()),
        }
    reconciliations = {}
    for pid in (P10, P11):
        report = json.loads((COMMUNITY / f"import_report_{pid}.json").read_text(encoding="utf-8"))
        registry_row = next(row for row in protected if row["package_id"] == pid)
        reconciliation = trusted.p10_runtime_contract_reconciliation() if pid == P10 else trusted.metadata_repair_reconciliation(pid)
        if registry_row.get("runtime_contract_reconciliation") != reconciliation or report.get("runtime_contract_reconciliation") != reconciliation:
            raise SystemExit("P12_BASELINE_ERROR: reconciliation drift " + pid)
        reconciliations[pid] = reconciliation
    return {
        "schemaVersion": "1.0", "preservesThroughPackage": 11,
        "registryProjection": compact(protected), "packages": packages,
        "metadataReconciliations": reconciliations,
        "nonP12GeneratedSourceProjection": source_only_projection(),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    observed = state()
    if args.check:
        if not BASELINE.exists() or json.loads(BASELINE.read_text(encoding="utf-8")) != observed:
            raise SystemExit("P12_BASELINE_CHECK_FAILED: Package 001-011 bytes/state drift")
        print("P12_PRESERVATION_BASELINE_OK packages=11 p10P11Reconciliations=true")
    else:
        BASELINE.parent.mkdir(parents=True, exist_ok=True)
        BASELINE.write_text(json.dumps(observed, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print("P12_PRESERVATION_BASELINE_CAPTURED packages=11 p10P11Reconciliations=true")


if __name__ == "__main__":
    main()
