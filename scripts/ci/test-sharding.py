#!/usr/bin/env python3
from __future__ import annotations
import argparse, copy, json, math, subprocess, tempfile
from pathlib import Path
from aggregate_shards import aggregate
from shard_protocol import ALGORITHM, FALLBACK, SCHEMA, assign, digest, load_contract, load_cost_manifest, partition_hash

def report(index: int, count: int, cases: list[str]) -> dict:
    values = [{"id": item, "semantic_input_hash": digest(item), "outcome": "passed", "duration_seconds": 1, "result_hash": digest(f"{item}|passed|{digest(item)}"), "resource_class": "cpu"} for item in cases]
    return {"schema_version": SCHEMA, "suite_id": "suite", "suite_version": "1", "suite_source_hash": digest("source"), "shard_index": index, "shard_count": count, "assignment_algorithm": ALGORITHM, "assignment_version": "1", "partition_hash": partition_hash(cases), "expected_ids": cases, "executed_ids": cases, "cases": values, "toolchain_identity": "test-toolchain", "toolchain_hash": digest("test-toolchain"), "policy_hash": digest("policy"), "index_hash": digest("index"), "commit": "local", "tree_classification": "local-observational", "observation": {"wall_clock_is_observational": True}}

def rejects(values: list[dict], label: str) -> None:
    with tempfile.TemporaryDirectory() as directory:
        paths = []
        for index, value in enumerate(values):
            path = Path(directory) / f"{index}.json"; path.write_text(json.dumps(value)); paths.append(path)
        try: aggregate(paths)
        except ValueError: return
    raise AssertionError(label)

def contract_for(value: dict, ids: list[str]) -> dict:
    return {"schema_version": "tracksmith-tutor-shard-contract/1", "suite_id": value["suite_id"], "suite_version": value["suite_version"], "suite_source_hash": value["suite_source_hash"], "policy_hash": value["policy_hash"], "index_hash": value["index_hash"], "case_ids": ids, "commit": value["commit"], "tree_classification": value["tree_classification"], "toolchain_identity": value["toolchain_identity"], "toolchain_hash": value["toolchain_hash"]}

def main() -> None:
    case_ids = ["a", "b", "c", "d", "e"]
    bins, algorithm = assign(case_ids, 3, {item: index + 1 for index, item in enumerate(case_ids)})
    assert algorithm == ALGORITHM and sorted(item for bucket in bins for item in bucket) == case_ids
    equal_bins, _ = assign(["case-b", "case-a", "case-c"], 2, {"case-a": 1, "case-b": 1, "case-c": 1})
    assert equal_bins == [["case-a", "case-c"], ["case-b"]]
    reports = [report(index, 3, cases) for index, cases in enumerate(bins)]
    contract = contract_for(reports[0], case_ids)
    assert aggregate([write_temp(item, index) for index, item in enumerate(reports)], case_ids, contract)["case_ids"] == case_ids
    rejects(reports[:-1], "missing shard accepted")
    duplicate = copy.deepcopy(reports); duplicate[1]["shard_index"] = 0; rejects(duplicate, "duplicate shard accepted")
    extra_report = copy.deepcopy(reports); extra_report[0]["unexpected"] = True; rejects(extra_report, "extra report field accepted")
    for coordinate, value in (("shard_index", True), ("shard_index", False), ("shard_count", True), ("shard_count", False)):
        invalid_coordinate = copy.deepcopy(reports); invalid_coordinate[0][coordinate] = value; rejects(invalid_coordinate, f"Boolean {coordinate} accepted")
    overlap = copy.deepcopy(reports); overlap[1]["expected_ids"].append(overlap[0]["expected_ids"][0]); overlap[1]["executed_ids"].append(overlap[0]["expected_ids"][0]); rejects(overlap, "overlap accepted")
    swapped = copy.deepcopy(reports); swapped[0]["cases"], swapped[1]["cases"] = swapped[1]["cases"], swapped[0]["cases"]; rejects(swapped, "cross-shard swapped cases accepted")
    string_executed = copy.deepcopy(reports); string_executed[0]["executed_ids"] = "not-a-list"; rejects(string_executed, "string executed IDs accepted")
    missing_case = copy.deepcopy(reports); missing_case[0]["cases"] = missing_case[0]["cases"][1:]; rejects(missing_case, "per-report missing case accepted")
    unexpected_case = copy.deepcopy(reports); unexpected_case[0]["cases"][0]["id"] = "unexpected"; rejects(unexpected_case, "per-report unexpected case accepted")
    duplicate_case = copy.deepcopy(reports); duplicate_case[0]["cases"].append(copy.deepcopy(duplicate_case[0]["cases"][0])); rejects(duplicate_case, "per-report duplicate case accepted")
    extra_case = copy.deepcopy(reports); extra_case[0]["cases"][0]["unexpected"] = True; rejects(extra_case, "extra case field accepted")
    corrupt = copy.deepcopy(reports); corrupt[0]["cases"][0]["result_hash"] = "bad"; rejects(corrupt, "corrupt accepted")
    for duration in (True, False, math.nan, math.inf, -1):
        invalid_duration = copy.deepcopy(reports); invalid_duration[0]["cases"][0]["duration_seconds"] = duration; rejects(invalid_duration, f"invalid duration accepted: {duration!r}")
    failed = copy.deepcopy(reports); failed[0]["cases"][0]["outcome"] = "failed"; rejects(failed, "failure accepted")
    changed = copy.deepcopy(reports); changed[0]["assignment_algorithm"] = "future"; rejects(changed, "algorithm change accepted")
    for field, value in (("commit", "other"), ("tree_classification", "other"), ("toolchain_identity", "other"), ("toolchain_hash", digest("other")), ("index_hash", digest("other")), ("policy_hash", digest("other")), ("suite_id", "other"), ("suite_version", "other"), ("suite_source_hash", digest("other"))):
        changed_identity = copy.deepcopy(reports); changed_identity[1][field] = value
        try: aggregate([write_temp(item, index) for index, item in enumerate(changed_identity)], case_ids, contract); raise AssertionError(f"mixed {field} accepted")
        except ValueError: pass
    rejects([report(0, 1, [])], "inferred empty universe accepted")
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "empty.json"; path.write_text(json.dumps(report(0, 1, [])))
        assert aggregate([path], [])["case_ids"] == []
    valid_paths = [write_temp(item, index) for index, item in enumerate(reports)]
    for invalid_expected in ("not-a-list", ["a", "a"], ["a", ""]):
        try: aggregate(valid_paths, invalid_expected); raise AssertionError("invalid expected IDs accepted")
        except ValueError: pass
    empty, fallback = assign([], 8); assert fallback == FALLBACK and len(empty) == 8
    root = Path(__file__).resolve().parents[2]
    manifest_path = root / "ci/tutor_test_costs.json"
    manifest = load_cost_manifest(manifest_path, root)
    assert manifest["case_ids"] == json.loads(manifest_path.read_text())["case_ids"]
    for mutate in (
        lambda item: item.update({"extra": True}), lambda item: item.pop("index_hash"),
        lambda item: item.update({"suite_source_hash": digest("wrong")}),
        lambda item: item["cost_seconds"].pop(item["case_ids"][0]),
        lambda item: item["cost_seconds"].update({"unexpected": 1}),
        lambda item: item["cost_seconds"].update({item["case_ids"][0]: True}),
    ):
        invalid_manifest = copy.deepcopy(manifest); mutate(invalid_manifest)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "costs.json"; path.write_text(json.dumps(invalid_manifest))
            try: load_cost_manifest(path, root); raise AssertionError("invalid cost manifest accepted")
            except ValueError: pass
    try: load_contract(Path("/definitely/missing.json")); raise AssertionError("missing contract accepted")
    except (OSError, ValueError): pass
    from cpu_budget import MAX_TUTOR_WORKERS, budget
    assert budget(MAX_TUTOR_WORKERS, 0) <= MAX_TUTOR_WORKERS
    try: budget(MAX_TUTOR_WORKERS + 1, 0); raise AssertionError("over-cap worker budget accepted")
    except ValueError: pass
    try: budget(1, -1); raise AssertionError("negative reserve accepted")
    except ValueError: pass
    for cap, reserve in ((True, 0), (False, 0), (1, True), (1, False)):
        try: budget(cap, reserve); raise AssertionError("Boolean CPU budget accepted")
        except ValueError: pass
    try: assign(case_ids, True); raise AssertionError("Boolean shard count accepted")
    except ValueError: pass
    try: assign(["a", 1], 2); raise AssertionError("non-string case ID accepted")
    except ValueError: pass
    logical = __import__("os").cpu_count() or 1
    if logical > 1: assert budget(MAX_TUTOR_WORKERS, max(1, logical - 2)) < budget(MAX_TUTOR_WORKERS, 0)
    print("test-sharding: LPT tie golden plus missing/duplicate/overlap/corrupt/empty/more-shards/failure/algorithm cases passed")

def binary_golden(binary: Path) -> None:
    root = Path(__file__).resolve().parents[2]
    binary = binary.resolve()
    costs = load_cost_manifest(root / "ci/tutor_test_costs.json", root)["cost_seconds"]
    all_ids = [line.split("\t", 1)[0] for line in subprocess.run([str(binary), "--list-tests"], cwd=root, check=True, capture_output=True, text=True).stdout.splitlines()]
    for count in (2, 3):
        expected, algorithm = assign(all_ids, count, costs)
        assert algorithm == ALGORITHM
        for index in range(count):
            output = subprocess.run([str(binary), "--list-tests", "--shard-index", str(index), "--shard-count", str(count)], cwd=root, check=True, capture_output=True, text=True).stdout.splitlines()
            actual = [line.split("\t", 1)[0] for line in output]
            assert actual == expected[index], f"Swift/Python assignment mismatch for {index}/{count}"
    for invalid_cost in (True, False):
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory); (fixture / "ci").mkdir()
            payload = json.loads((root / "ci/tutor_test_costs.json").read_text())
            payload["cost_seconds"][all_ids[0]] = invalid_cost
            (fixture / "ci/tutor_test_costs.json").write_text(json.dumps(payload))
            expected, algorithm = assign(all_ids, 3, payload["cost_seconds"])
            assert algorithm == FALLBACK
            for index in range(3):
                output = subprocess.run([str(binary), "--list-tests", "--shard-index", str(index), "--shard-count", "3"], cwd=fixture, check=True, capture_output=True, text=True).stdout.splitlines()
                actual = [line.split("\t", 1)[0] for line in output]
                assert actual == expected[index], f"Swift/Python Boolean-cost fallback mismatch for {index}/3"
    empty, algorithm = assign([], 3, costs)
    assert algorithm == FALLBACK and empty == [[], [], []]
    for index in range(3):
        output = subprocess.run([str(binary), "--list-tests", "--exclude", "tutor-conversation/*", "--shard-index", str(index), "--shard-count", "3"], cwd=root, check=True, capture_output=True, text=True).stdout
        assert output == "", "Swift empty-selection shard is not empty"
    invalid = subprocess.run([str(binary), "--include", "tutor-conversation/01-tool-firewall", "--include", "typo"], cwd=root, capture_output=True, text=True)
    assert invalid.returncode == 64 and "every --include selector" in invalid.stderr
    print("test-sharding: release-binary Swift/Python assignment golden passed")

_TEMPS: list[tempfile.TemporaryDirectory] = []
def write_temp(value: dict, index: int) -> Path:
    temp = tempfile.TemporaryDirectory(); _TEMPS.append(temp); path = Path(temp.name) / f"{index}.json"; path.write_text(json.dumps(value)); return path
if __name__ == "__main__":
    parser = argparse.ArgumentParser(); parser.add_argument("--binary", type=Path); args = parser.parse_args()
    main()
    if args.binary: binary_golden(args.binary)
