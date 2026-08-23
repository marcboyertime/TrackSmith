#!/usr/bin/env python3
"""Portable fail-closed product-resource boundary scanner for the Linux policy lane."""
from __future__ import annotations

import argparse
import pathlib
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
RESOURCE_MARKERS = (
    b"tracksmith-corpus-017",
    b"expected_answer",
    b"fixture_alias",
    b"evaluation_case",
)
SOURCE_MARKERS = (
    b"p19-",
    b"acceptable_diagnosis_families",
    b"expected_answer",
    b"fixture_alias",
    b"evaluation_case",
)


def fail(message: str) -> None:
    raise RuntimeError(f"product resource policy failed: {message}")


def require_regular(path: pathlib.Path, description: str) -> None:
    if not path.is_file() or path.is_symlink():
        fail(f"{description} must be a regular file: {path}")


def scan_files(label: str, paths: list[pathlib.Path], markers: tuple[bytes, ...]) -> None:
    scanned = 0
    for path in paths:
        require_regular(path, label)
        payload = path.read_bytes().lower()
        scanned += 1
        for marker in markers:
            if marker in payload:
                fail(f"{label} contains forbidden marker {marker.decode('ascii')!r}: {path}")
    print(f"{label}: scanned {scanned} file(s); {len(markers)} forbidden markers absent")


def source_files(source_roots: list[pathlib.Path]) -> list[pathlib.Path]:
    files: list[pathlib.Path] = []
    for root in source_roots:
        if not root.is_dir() or root.is_symlink():
            fail(f"source root must be a real directory: {root}")
        for path in sorted(root.rglob("*")):
            if path.is_symlink():
                fail(f"source scan rejects symlinks: {path}")
            if path.is_file():
                files.append(path)
    if not files:
        fail("source scan found no files")
    return files


def check(resources: pathlib.Path, source_roots: list[pathlib.Path]) -> None:
    if not resources.is_dir() or resources.is_symlink():
        fail(f"resources must be a real directory: {resources}")
    forbidden_golden = resources / "tracksmith-corpus-017-golden-tutor-conversations-level-adaptation.json"
    if forbidden_golden.exists() or forbidden_golden.is_symlink():
        fail(f"forbidden golden corpus is present: {forbidden_golden}")
    json_files = sorted(path for path in resources.glob("*.json") if path.is_file() and not path.is_symlink())
    expected_manifest = resources / "CandidateRetrieval.manifest.json"
    if json_files != [expected_manifest]:
        fail("resources must contain exactly CandidateRetrieval.manifest.json as their only top-level JSON file")
    scan_files(
        "product retrieval resource scan",
        [resources / "CandidateRetrieval.sqlite", expected_manifest],
        RESOURCE_MARKERS,
    )
    scan_files("product source scan", source_files(source_roots), SOURCE_MARKERS)


def self_test() -> None:
    with tempfile.TemporaryDirectory() as temporary:
        root = pathlib.Path(temporary)

        def fixture(name: str) -> tuple[pathlib.Path, list[pathlib.Path]]:
            case = root / name; case.mkdir()
            resources = case / "Resources"; resources.mkdir()
            source_a = case / "TutorConversation"; source_a.mkdir()
            source_b = case / "ProductionTutor"; source_b.mkdir()
            (resources / "CandidateRetrieval.sqlite").write_bytes(b"sqlite fixture")
            (resources / "CandidateRetrieval.manifest.json").write_text('{"fixture":"safe"}')
            (source_a / "Tutor.swift").write_text("struct Tutor {}\n")
            (source_b / "Retriever.swift").write_text("struct Retriever {}\n")
            return resources, [source_a, source_b]

        resources, roots = fixture("safe")
        check(resources, roots)
        cases: list[tuple[str, pathlib.Path, list[pathlib.Path]]] = []
        resources, roots = fixture("seeded-resource-marker")
        (resources / "CandidateRetrieval.sqlite").write_bytes(b"expected_answer")
        cases.append(("seeded-resource-marker", resources, roots))
        resources, roots = fixture("seeded-source-marker")
        (roots[0] / "Tutor.swift").write_text("let scenario = \"p19-forbidden\"\n")
        cases.append(("seeded-source-marker", resources, roots))
        resources, roots = fixture("unexpected-json")
        (resources / "unexpected.json").write_text("{}")
        cases.append(("unexpected-json", resources, roots))
        resources, roots = fixture("golden-corpus")
        (resources / "tracksmith-corpus-017-golden-tutor-conversations-level-adaptation.json").write_text("{}")
        cases.append(("golden-corpus", resources, roots))
        for name, case_resources, case_roots in cases:
            try:
                check(case_resources, case_roots)
            except RuntimeError:
                continue
            raise AssertionError(f"negative fixture was accepted: {name}")
    print("product-resource-policy self-test: both scans and 4 negative fixtures passed")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--resources", type=pathlib.Path, default=ROOT / "packages/ProductionTutor/Sources/ProductionTutor/Resources")
    parser.add_argument("--source-root", type=pathlib.Path, action="append")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return 0
    roots = args.source_root or [
        ROOT / "packages/TutorConversation/Sources",
        ROOT / "packages/ProductionTutor/Sources",
    ]
    try:
        check(args.resources, roots)
    except RuntimeError as error:
        print(f"error: {error}")
        return 1
    print("product-resource-policy: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
