#!/usr/bin/env python3
"""Validate unsigned built product identity and write compact CI evidence."""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import plistlib
import tempfile


APP_ID = "com.marcboyer.logicaudioassistant"
AU_ID = "com.marcboyer.logicaudioassistant.AudioUnit"
AU_COMPONENT = {"manufacturer": "ExAI", "type": "aufx", "subtype": "LgAA"}


def sha256(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def tree_bytes(path: pathlib.Path) -> int:
    return sum(item.stat().st_size for item in path.rglob("*") if item.is_file())


def read_plist(path: pathlib.Path) -> dict:
    if not path.is_file():
        raise ValueError(f"missing Info.plist: {path}")
    value = plistlib.loads(path.read_bytes())
    if not isinstance(value, dict):
        raise ValueError(f"Info.plist is not a dictionary: {path}")
    return value


def report(app: pathlib.Path, receipt: pathlib.Path, output: pathlib.Path, xcode_version: str, runner_image: str, runner_architecture: str) -> dict:
    if not app.is_dir() or app.suffix != ".app":
        raise ValueError(f"built app missing or invalid: {app}")
    au = app / "Contents/PlugIns/Logic Audio Assistant AU.appex"
    if not au.is_dir():
        raise ValueError(f"embedded Audio Unit appex missing: {au}")
    app_info, au_info = read_plist(app / "Contents/Info.plist"), read_plist(au / "Contents/Info.plist")
    if app_info.get("CFBundleIdentifier") != APP_ID:
        raise ValueError("Companion bundle identifier drift")
    if au_info.get("CFBundleIdentifier") != AU_ID:
        raise ValueError("Audio Unit bundle identifier drift")
    components = au_info.get("NSExtension", {}).get("NSExtensionAttributes", {}).get("AudioComponents", [])
    if not isinstance(components, list) or not any(all(component.get(key) == value for key, value in AU_COMPONENT.items()) for component in components if isinstance(component, dict)):
        raise ValueError("Audio Unit component identity drift")
    resources = list(app.rglob("ProductionTutor.bundle/Contents/Resources"))
    if len(resources) != 1:
        raise ValueError(f"expected one built ProductionTutor resource directory, found {len(resources)}")
    sqlite, manifest = resources[0] / "CandidateRetrieval.sqlite", resources[0] / "CandidateRetrieval.manifest.json"
    if not sqlite.is_file() or not manifest.is_file() or not receipt.is_file():
        raise ValueError("built retrieval resources or receipt missing")
    value = {
        "evidence_class": "unsigned hosted build resource/receipt evidence; not signing, install, Logic, provider, or listening evidence",
        "xcodegen_version": "2.46.0",
        "xcode_version": xcode_version,
        "runner": {"image": runner_image, "architecture": runner_architecture},
        "app": {"bundle_identifier": APP_ID, "bytes": tree_bytes(app)},
        "audio_unit": {"bundle_identifier": AU_ID, "component": AU_COMPONENT, "bytes": tree_bytes(au)},
        "production_tutor_resources": {
            "candidate_retrieval_sqlite": {"bytes": sqlite.stat().st_size, "sha256": sha256(sqlite)},
            "candidate_retrieval_manifest": {"bytes": manifest.stat().st_size, "sha256": sha256(manifest)}
        },
        "receipt": {"bytes": receipt.stat().st_size, "sha256": sha256(receipt)}
    }
    output.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")
    return value


def self_test() -> None:
    with tempfile.TemporaryDirectory(prefix="tracksmith-xcode-report-") as temporary:
        root = pathlib.Path(temporary); app = root / "Logic Audio Assistant.app"; au = app / "Contents/PlugIns/Logic Audio Assistant AU.appex"
        resources = app / "Contents/Frameworks/ProductionTutor.bundle/Contents/Resources"
        resources.mkdir(parents=True); (au / "Contents").mkdir(parents=True)
        (app / "Contents/Info.plist").write_bytes(plistlib.dumps({"CFBundleIdentifier": APP_ID}))
        (au / "Contents/Info.plist").write_bytes(plistlib.dumps({"CFBundleIdentifier": AU_ID, "NSExtension": {"NSExtensionAttributes": {"AudioComponents": [AU_COMPONENT]}}}))
        (resources / "CandidateRetrieval.sqlite").write_bytes(b"sqlite-fixture")
        (resources / "CandidateRetrieval.manifest.json").write_text("{}\n")
        receipt, output = root / "receipt.json", root / "report.json"; receipt.write_text("{}\n")
        value = report(app, receipt, output, "Xcode fixture", "fixture", "arm64")
        assert value["audio_unit"]["component"] == AU_COMPONENT and json.loads(output.read_text())["app"]["bundle_identifier"] == APP_ID
    print("xcode-products-report self-test: identity and compact resource evidence passed")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--app", type=pathlib.Path)
    parser.add_argument("--receipt", type=pathlib.Path)
    parser.add_argument("--output", type=pathlib.Path)
    parser.add_argument("--xcode-version")
    parser.add_argument("--runner-image")
    parser.add_argument("--runner-architecture")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test: self_test(); return 0
    if not all((args.app, args.receipt, args.output, args.xcode_version, args.runner_image, args.runner_architecture)):
        parser.error("--app, --receipt, --output, --xcode-version, --runner-image, and --runner-architecture are required")
    report(args.app, args.receipt, args.output, args.xcode_version, args.runner_image, args.runner_architecture)
    return 0


if __name__ == "__main__": raise SystemExit(main())
