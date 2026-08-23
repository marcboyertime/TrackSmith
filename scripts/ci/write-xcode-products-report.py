#!/usr/bin/env python3
"""Validate unsigned built product identity and write compact CI evidence."""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import plistlib
import shutil
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


def production_tutor_resources(app: pathlib.Path) -> tuple[pathlib.Path, pathlib.Path, pathlib.Path]:
    bundles = sorted(path for path in app.rglob("*") if path.is_dir() and path.name.endswith("ProductionTutor.bundle"))
    if len(bundles) != 1:
        raise ValueError(f"expected exactly one built *ProductionTutor.bundle, found {len(bundles)}")
    if bundles[0].is_symlink():
        raise ValueError("built ProductionTutor bundle is symlinked")
    resources = bundles[0] / "Contents/Resources"
    if not resources.is_dir() or resources.is_symlink():
        raise ValueError("built ProductionTutor resource directory missing or symlinked")
    files = sorted(path for path in resources.rglob("*") if path.is_file())
    if any(path.is_symlink() for path in resources.rglob("*")):
        raise ValueError("built ProductionTutor resources contain a symlink")
    expected = {"CandidateRetrieval.sqlite", "CandidateRetrieval.manifest.json"}
    actual = {str(path.relative_to(resources)) for path in files}
    if actual != expected:
        raise ValueError(f"built ProductionTutor resource layout drift: expected {sorted(expected)}, found {sorted(actual)}")
    return bundles[0], resources / "CandidateRetrieval.sqlite", resources / "CandidateRetrieval.manifest.json"


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
    bundle, sqlite, manifest = production_tutor_resources(app)
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
            "bundle_name": bundle.name,
            "candidate_retrieval_sqlite": {"bytes": sqlite.stat().st_size, "sha256": sha256(sqlite)},
            "candidate_retrieval_manifest": {"bytes": manifest.stat().st_size, "sha256": sha256(manifest)}
        },
        "receipt": {"bytes": receipt.stat().st_size, "sha256": sha256(receipt)}
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")
    return value


def self_test() -> None:
    with tempfile.TemporaryDirectory(prefix="tracksmith-xcode-report-") as temporary:
        root = pathlib.Path(temporary); app = root / "Logic Audio Assistant.app"; au = app / "Contents/PlugIns/Logic Audio Assistant AU.appex"
        resources = app / "Contents/Frameworks/LogicAudioAssistant_ProductionTutor.bundle/Contents/Resources"
        resources.mkdir(parents=True); (au / "Contents").mkdir(parents=True)
        (app / "Contents/Info.plist").write_bytes(plistlib.dumps({"CFBundleIdentifier": APP_ID}))
        (au / "Contents/Info.plist").write_bytes(plistlib.dumps({"CFBundleIdentifier": AU_ID, "NSExtension": {"NSExtensionAttributes": {"AudioComponents": [AU_COMPONENT]}}}))
        (resources / "CandidateRetrieval.sqlite").write_bytes(b"sqlite-fixture")
        (resources / "CandidateRetrieval.manifest.json").write_text("{}\n")
        receipt, output = root / "receipt.json", root / "report.json"; receipt.write_text("{}\n")
        value = report(app, receipt, output, "Xcode fixture", "fixture", "arm64")
        assert value["audio_unit"]["component"] == AU_COMPONENT and value["production_tutor_resources"]["bundle_name"] == "LogicAudioAssistant_ProductionTutor.bundle"
        bundle = resources.parent.parent; real_bundle = bundle.with_name("real.bundle")
        bundle.rename(real_bundle); bundle.symlink_to(real_bundle.name, target_is_directory=True)
        try: report(app, receipt, output, "Xcode fixture", "fixture", "arm64")
        except ValueError: pass
        else: raise AssertionError("symlinked ProductionTutor bundle fixture was accepted")
        bundle.unlink(); real_bundle.rename(bundle)
        resources.parent.parent.rename(resources.parent.parent.with_name("Hidden.bundle"))
        try: report(app, receipt, output, "Xcode fixture", "fixture", "arm64")
        except ValueError: pass
        else: raise AssertionError("zero ProductionTutor bundle fixture was accepted")
        hidden = resources.parent.parent.with_name("Hidden.bundle"); hidden.rename(resources.parent.parent)
        duplicate = app / "Contents/Frameworks/Other_ProductionTutor.bundle/Contents/Resources"; duplicate.mkdir(parents=True)
        (duplicate / "CandidateRetrieval.sqlite").write_bytes(b"duplicate")
        (duplicate / "CandidateRetrieval.manifest.json").write_text("{}\n")
        try: report(app, receipt, output, "Xcode fixture", "fixture", "arm64")
        except ValueError: pass
        else: raise AssertionError("multiple ProductionTutor bundle fixture was accepted")
        shutil.rmtree(duplicate.parent.parent)
        (resources / "unexpected.json").write_text("{}\n")
        try: report(app, receipt, output, "Xcode fixture", "fixture", "arm64")
        except ValueError: pass
        else: raise AssertionError("unexpected ProductionTutor resource was accepted")
    print("xcode-products-report self-test: prefixed bundle identity and 4 negative layouts passed")


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
