#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = json.loads((ROOT / "package_manifest.json").read_text(encoding="utf-8"))


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def load_registry(path: Path) -> dict:
    if not path.exists():
        return {"contract": "tracksmith-community-package-registry", "version": "1.0", "packages": []}
    value = json.loads(path.read_text(encoding="utf-8"))
    if value.get("contract") != "tracksmith-community-package-registry":
        raise SystemExit(f"Unexpected package registry contract at {path}")
    return value


def read_dependency_map(path: Path | None) -> dict[str, str]:
    if path is None:
        return {}
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict) or not all(isinstance(k, str) and isinstance(v, str) for k, v in value.items()):
        raise SystemExit("Dependency map must be a JSON object of declared ID -> installed ID.")
    return value


def current_git_head(target: Path) -> str:
    result = subprocess.run(
        ["git", "-C", str(target), "rev-parse", "HEAD"],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def run_package_validation() -> None:
    subprocess.run([sys.executable, str(ROOT / "tools" / "validate_package.py")], check=True)


def package_record_ids(root: Path) -> set[str]:
    ids: set[str] = set()
    for folder in ("corpus", "knowledge_candidates", "sources"):
        base = root / folder
        if not base.exists():
            continue
        for path in sorted(base.glob("*.jsonl")):
            with path.open(encoding="utf-8") as handle:
                for line in handle:
                    if not line.strip():
                        continue
                    value = json.loads(line)
                    identifier = value.get("id")
                    if isinstance(identifier, str):
                        ids.add(identifier)
    return ids


def detect_duplicate_ids(packages_root: Path, destination: Path) -> list[str]:
    incoming = package_record_ids(ROOT)
    duplicates: set[str] = set()
    if not packages_root.exists():
        return []
    for package_dir in sorted(packages_root.iterdir()):
        if not package_dir.is_dir() or package_dir.resolve() == destination.resolve():
            continue
        duplicates.update(incoming.intersection(package_record_ids(package_dir)))
        if len(duplicates) > 100:
            break
    return sorted(duplicates)


def atomic_json_write(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    data = json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n"
    fd, temporary = tempfile.mkstemp(prefix=path.name + ".", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate and safely stage this corpus package in a TrackSmith checkout.")
    parser.add_argument("--target", required=True, help="Path to the TrackSmith Git checkout")
    parser.add_argument("--dry-run", action="store_true", help="Run every preflight check without changing the target")
    parser.add_argument("--force", action="store_true", help="Replace an existing copy of the same package after preflight")
    parser.add_argument(
        "--dependency-map",
        type=Path,
        help="Optional JSON object mapping standardized dependency IDs to legacy installed package IDs",
    )
    parser.add_argument(
        "--allow-missing-dependencies",
        action="store_true",
        help="Stage despite unresolved dependencies. Intended only for an explicitly documented legacy migration.",
    )
    args = parser.parse_args()

    target = Path(args.target).expanduser().resolve()
    if not (target / ".git").exists():
        raise SystemExit("Target is not a Git checkout.")

    run_package_validation()
    start_head = current_git_head(target)

    community_root = target / "research" / "community_knowledge"
    packages_root = community_root / "packages"
    destination = packages_root / MANIFEST["package_id"]
    registry_path = community_root / "package_registry.json"
    registry = load_registry(registry_path)
    installed_ids = {entry.get("package_id") for entry in registry.get("packages", []) if entry.get("package_id")}
    mapping = read_dependency_map(args.dependency_map)

    dependency_resolution: dict[str, str | None] = {}
    missing: list[str] = []
    for declared in MANIFEST["depends_on"]:
        actual = mapping.get(declared, declared)
        if actual in installed_ids:
            dependency_resolution[declared] = actual
        else:
            dependency_resolution[declared] = None
            missing.append(declared)

    if missing and not args.allow_missing_dependencies:
        details = "\n".join(f"  - {item}" for item in missing)
        raise SystemExit(
            "Required corpus dependencies were not resolved:\n"
            + details
            + "\nUse --dependency-map for legacy package IDs, or --allow-missing-dependencies only after documenting the migration."
        )

    duplicates = detect_duplicate_ids(packages_root, destination)
    if duplicates:
        preview = "\n".join(f"  - {item}" for item in duplicates[:20])
        raise SystemExit(f"Incoming IDs collide with other installed packages:\n{preview}")

    if destination.exists() and not args.force:
        raise SystemExit("Destination already exists. Review it first; use --force only for an intentional same-package replacement.")

    plan = {
        "status": "dry_run" if args.dry_run else "planned",
        "package_id": MANIFEST["package_id"],
        "package_version": MANIFEST["package_version"],
        "contract_version": MANIFEST["contract_version"],
        "target": str(target),
        "target_start_head": start_head,
        "destination": str(destination),
        "dependency_resolution": dependency_resolution,
        "missing_dependencies_allowed": bool(missing and args.allow_missing_dependencies),
        "duplicate_id_count": len(duplicates),
        "record_counts": MANIFEST["record_counts"],
        "package_manifest_sha256": sha256(ROOT / "package_manifest.json"),
        "review_state": MANIFEST["review_state"],
        "logic_procedure_status": MANIFEST["logic_procedure_status"],
        "does_not_modify": [
            "GeneralTutorKnowledge.generated.swift",
            "Logic project state",
            "Audio Unit state",
            "prior corpus package source files",
        ],
    }
    print(json.dumps(plan, indent=2, sort_keys=True))
    if args.dry_run:
        return

    packages_root.mkdir(parents=True, exist_ok=True)
    temporary = packages_root / f".{MANIFEST['package_id']}.importing-{os.getpid()}"
    if temporary.exists():
        shutil.rmtree(temporary)
    try:
        shutil.copytree(ROOT, temporary, ignore=shutil.ignore_patterns("*.zip", "__pycache__", ".DS_Store"))
        if destination.exists():
            shutil.rmtree(destination)
        os.replace(temporary, destination)
    finally:
        if temporary.exists():
            shutil.rmtree(temporary)

    packages = [entry for entry in registry.get("packages", []) if entry.get("package_id") != MANIFEST["package_id"]]
    packages.append(
        {
            "package_id": MANIFEST["package_id"],
            "package_number": MANIFEST["package_number"],
            "package_version": MANIFEST["package_version"],
            "contract_version": MANIFEST["contract_version"],
            "path": str(destination.relative_to(target)),
            "review_state": MANIFEST["review_state"],
            "logic_procedure_status": MANIFEST["logic_procedure_status"],
            "depends_on": MANIFEST["depends_on"],
            "dependency_resolution": dependency_resolution,
            "package_manifest_sha256": plan["package_manifest_sha256"],
        }
    )
    registry["packages"] = sorted(packages, key=lambda entry: (entry.get("package_number", 999999), entry.get("package_id", "")))
    atomic_json_write(registry_path, registry)

    report = {
        **plan,
        "status": "staged",
        "target_end_head": current_git_head(target),
        "registry": str(registry_path.relative_to(target)),
        "next_required_work": [
            "Connect the package to the existing unified retrieval database/index.",
            "Run TrackSmith retrieval and Tutor response tests.",
            "Review candidate knowledge before promotion.",
            "Verify candidate Logic procedures against the installed version before trusted use.",
        ],
    }
    report_path = community_root / f"import_report_{MANIFEST['package_id']}.json"
    atomic_json_write(report_path, report)
    print(f"Staged {MANIFEST['package_id']} and wrote {report_path}")


if __name__ == "__main__":
    main()
