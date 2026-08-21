#!/usr/bin/env python3
"""Capture or verify the byte/state preservation contract for Packages 001–009."""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import community_corpus_import as trusted


ROOT = pathlib.Path(__file__).resolve().parents[2]
COMMUNITY = ROOT / "research/community_knowledge"
KNOWLEDGE = ROOT / "research/knowledge"
RESOURCES = ROOT / "research/community_knowledge/runtime_projection/p16"
EVALUATIONS = ROOT / "tools/TutorConversationTests/Resources"
DESCRIPTOR = ROOT / "packages/ProductionTutor/Sources/ProductionTutor/CommunityCandidateCorpus.generated.swift"
BASELINE = COMMUNITY / "preservation_baselines/tracksmith-corpus-010-flex-time-manual-timing.json"


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def compact(value: object) -> str:
    return sha(json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode())


def tree(path: pathlib.Path) -> dict[str, object]:
    files, value = trusted.preservation_tree(path)
    return {"files": files, "tree": value}


def package_path(package_id: str) -> pathlib.Path:
    return COMMUNITY / "packages" / package_id if package_id.startswith("tracksmith-corpus") else KNOWLEDGE / package_id


def generated_non_p10_projection() -> str:
    text = (ROOT / "packages/ProductionTutor/Sources/ProductionTutor/GeneralTutorKnowledge.generated.swift").read_text()
    start, end = text.find('#"""'), text.rfind('"""#')
    if start < 0 or end < 0:
        raise SystemExit("P10_BASELINE_ERROR: generated knowledge payload unreadable")
    payload = json.loads(text[start + 4:end])
    payload["sources"] = [source for source in payload.get("sources", []) if not str(source.get("id", "")).startswith(("pkg010.", "pkg011."))]
    return compact(payload)


def state() -> dict[str, object]:
    registry = json.loads((COMMUNITY / "package_registry.json").read_text())
    p10_id = "tracksmith-corpus-010-flex-time-manual-timing"
    p10_rows = [entry for entry in registry["packages"] if entry.get("package_id") == p10_id]
    p10_report = json.loads((COMMUNITY / ("import_report_" + p10_id + ".json")).read_text())
    reconciliation = trusted.p10_runtime_contract_reconciliation(COMMUNITY / "packages" / p10_id)
    if len(p10_rows) != 1 or p10_rows[0].get("runtime_contract_reconciliation") != reconciliation or p10_report.get("runtime_contract_reconciliation") != reconciliation:
        raise SystemExit("P10_BASELINE_ERROR: staged P10 runtime-contract reconciliation drift")
    packages = [entry for entry in registry["packages"] if entry.get("package_number", 0) <= 9]
    sources = json.loads((KNOWLEDGE / "general-tutor-source-registry.json").read_text())["sources"]
    queue = json.loads((KNOWLEDGE / "general-tutor-review-queue.json").read_text())["candidates"]
    descriptor_lines = DESCRIPTOR.read_text().splitlines(keepends=True)
    captured: dict[str, object] = {}
    for entry in packages:
        package_id = entry["package_id"]
        path = package_path(package_id)
        manifest = path / ("package_manifest.json" if (path / "package_manifest.json").exists() else "manifest.json")
        line = next((line for line in descriptor_lines if f'packageID: "{package_id}"' in line), None)
        if line is None:
            raise SystemExit("P10_BASELINE_ERROR: descriptor missing " + package_id)
        captured[package_id] = {
            **tree(path),
            "manifest": sha(manifest.read_bytes()),
            "runtime": sha((RESOURCES / (package_id + ".json")).read_bytes()),
            "evaluation": sha((EVALUATIONS / (package_id + "-evaluation.json")).read_bytes()),
            "sourceProjection": compact([item for item in sources if item.get("candidateCorpus") == package_id]),
            "queueProjection": compact([item for item in queue if item.get("candidateCorpus") == package_id]),
            "descriptorLine": sha(line.rstrip(",\n").encode()),
        }
    return {
        "schemaVersion": "1.0",
        "preservesThroughPackage": 9,
        "registryProjection": compact(packages),
        "packages": captured,
        "nonP10GeneratedAdviceProjection": generated_non_p10_projection(),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    observed = state()
    if args.check:
        if not BASELINE.exists() or not trusted.preservation_baseline_matches(json.loads(BASELINE.read_text()), observed):
            raise SystemExit("P10_BASELINE_CHECK_FAILED: Package 001–009 bytes/state drift")
        print("P10_PRESERVATION_BASELINE_OK packages=9")
    else:
        BASELINE.parent.mkdir(parents=True, exist_ok=True)
        existing = json.loads(BASELINE.read_text()) if BASELINE.exists() else {}
        BASELINE.write_text(json.dumps(trusted.preservation_capture_document(existing, observed), indent=2, sort_keys=True) + "\n")
        print("P10_PRESERVATION_BASELINE_CAPTURED packages=9")


if __name__ == "__main__":
    main()
