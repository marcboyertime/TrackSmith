#!/usr/bin/env python3
"""Run Tutor shards through the validated local-only deterministic case cache.

The cache is deliberately an execution layer, not an artifact transport.  A
cold cache uses the normal direct-binary shard topology; warm or partially
warm runs execute only cache misses and rebuild contract-valid reports before
the ordinary exhaustive aggregate runs.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

import deterministic_case_cache as cache
from shard_protocol import ALGORITHM, assign, canonical_bytes, digest, load_contract, load_cost_manifest, partition_hash


def parse_list(path: Path, expected: list[str]) -> dict[str, tuple[str, str, str, str]]:
    values: dict[str, tuple[str, str, str, str]] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        fields = line.split("\t")
        if len(fields) != 5 or not all(fields) or any(len(value) != 64 or any(character not in "0123456789abcdef" for character in value) for value in fields[3:]):
            raise ValueError("release binary list must contain exact ID, resource class, name, case, and shared hashes")
        identifier, resource_class, name, case_implementation, shared_evaluator = fields
        if identifier in values:
            raise ValueError("release binary list contains duplicate IDs")
        values[identifier] = (resource_class, name, case_implementation, shared_evaluator)
    if list(values) != expected:
        raise ValueError("release binary list does not match the validated contract universe")
    return values


def semantic(contract: dict[str, Any], identifier: str, resource_class: str, name: str, case_implementation: str, shared_evaluator: str) -> str:
    return digest("|".join((contract["suite_id"], contract["suite_version"], identifier, name, resource_class, case_implementation, shared_evaluator, contract["policy_hash"], contract["index_hash"], "ordinary-case-schema-v2")))


def components(contract: dict[str, Any], identifier: str, semantic_hash: str, shared_evaluator: str) -> dict[str, str]:
    return {
        "suite_id": contract["suite_id"], "suite_version": contract["suite_version"],
        "source_hash": shared_evaluator, "policy_hash": contract["policy_hash"],
        "index_hash": contract["index_hash"], "toolchain_hash": contract["toolchain_hash"],
        "case_id": identifier, "semantic_input_hash": semantic_hash,
    }


def validate_case(value: dict[str, Any], identifier: str, semantic_hash: str, resource_class: str) -> dict[str, Any]:
    required = {"id", "semantic_input_hash", "outcome", "duration_seconds", "result_hash", "resource_class"}
    if not isinstance(value, dict) or set(value) != required or value.get("id") != identifier or value.get("semantic_input_hash") != semantic_hash or value.get("outcome") != "passed" or value.get("resource_class") != resource_class or value.get("result_hash") != digest(f"{identifier}|passed|{semantic_hash}"):
        raise ValueError(f"corrupt fresh result for {identifier}")
    return value


def report(contract: dict[str, Any], shard_index: int, shard_count: int, identifiers: list[str], cases: list[dict[str, Any]]) -> dict[str, Any]:
    ordered = sorted(identifiers)
    if sorted(case["id"] for case in cases) != ordered:
        raise ValueError("cached shard report is incomplete")
    return {
        "schema_version": "tracksmith-shard-report/1", "suite_id": contract["suite_id"], "suite_version": contract["suite_version"],
        "suite_source_hash": contract["suite_source_hash"], "commit": contract["commit"], "tree_classification": contract["tree_classification"],
        "shard_index": shard_index, "shard_count": shard_count, "assignment_algorithm": ALGORITHM, "assignment_version": "1",
        "partition_hash": partition_hash(ordered), "expected_ids": ordered, "executed_ids": ordered,
        "cases": sorted(cases, key=lambda value: value["id"]), "toolchain_identity": contract["toolchain_identity"],
        "toolchain_hash": contract["toolchain_hash"], "policy_hash": contract["policy_hash"], "index_hash": contract["index_hash"],
        "observation": {"wall_clock_is_observational": True},
    }


def invoke(binary: Path, arguments: list[str], output: Path) -> None:
    result = subprocess.run([str(binary), *arguments, "--output-json", str(output)], text=True, capture_output=True)
    if result.returncode:
        raise ValueError(f"Tutor binary failed ({result.returncode}): {result.stderr.strip() or result.stdout.strip()}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", type=Path, required=True); parser.add_argument("--contract", type=Path, required=True)
    parser.add_argument("--list", type=Path, required=True); parser.add_argument("--cache-root", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True); parser.add_argument("--shard-count", type=int, required=True)
    parser.add_argument("--cost-manifest", type=Path, required=True); parser.add_argument("--repo-root", type=Path, required=True)
    args = parser.parse_args()
    try:
        if args.shard_count < 1 or args.shard_count > 3:
            raise ValueError("shard count must be within the enforced 1...3 worker bound")
        contract = load_contract(args.contract)
        listed = parse_list(args.list, contract["case_ids"])
        manifest = load_cost_manifest(args.cost_manifest, args.repo_root)
        assignments, algorithm = assign(contract["case_ids"], args.shard_count, manifest["cost_seconds"])
        if algorithm != ALGORITHM:
            raise ValueError("cache execution requires the validated LPT assignment")
        cases: dict[str, dict[str, Any]] = {}
        misses: list[str] = []
        for identifier in contract["case_ids"]:
            resource_class, name, case_implementation, shared_evaluator = listed[identifier]
            semantic_hash = semantic(contract, identifier, resource_class, name, case_implementation, shared_evaluator)
            cached = cache.load(args.cache_root, components(contract, identifier, semantic_hash, shared_evaluator))
            if cached is None:
                misses.append(identifier)
            else:
                cases[identifier] = {"id": identifier, "semantic_input_hash": semantic_hash, "outcome": "passed", "duration_seconds": 0, "result_hash": cached["result_hash"], "resource_class": resource_class}
        args.output_dir.mkdir(parents=True, exist_ok=True)
        if len(misses) == len(contract["case_ids"]):
            mode = "cold-native-shards"
            workers: list[tuple[int, subprocess.Popen[str]]] = []
            for index in range(args.shard_count):
                workers.append((index, subprocess.Popen([str(args.binary), "--shard-index", str(index), "--shard-count", str(args.shard_count), "--output-json", str(args.output_dir / f"shard-{index}.json")], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)))
            failed: list[str] = []
            for index, worker in workers:
                output, _ = worker.communicate()
                (args.output_dir / f"shard-{index}.log").write_text(output, encoding="utf-8")
                if worker.returncode:
                    failed.append(f"shard {index}: {output.strip()}")
            if failed:
                raise ValueError("; ".join(failed))
            for index in range(args.shard_count):
                native = json.loads((args.output_dir / f"shard-{index}.json").read_text(encoding="utf-8"))
                for value in native.get("cases", []):
                    identifier = value.get("id")
                    if identifier not in listed:
                        raise ValueError("native report has an unexpected case")
                    resource_class, name, case_implementation, shared_evaluator = listed[identifier]
                    semantic_hash = semantic(contract, identifier, resource_class, name, case_implementation, shared_evaluator)
                    cases[identifier] = validate_case(value, identifier, semantic_hash, resource_class)
                    cache.store(args.cache_root, components(contract, identifier, semantic_hash, shared_evaluator), {"case_id": identifier, "semantic_input_hash": semantic_hash, "outcome": "passed", "result_hash": value["result_hash"]})
        else:
            mode = "warm-cache" if not misses else "partial-cache"
            for ordinal, identifier in enumerate(misses):
                resource_class, name, case_implementation, shared_evaluator = listed[identifier]
                semantic_hash = semantic(contract, identifier, resource_class, name, case_implementation, shared_evaluator)
                raw = args.output_dir / f"miss-{ordinal}.json"
                invoke(args.binary, ["--include", identifier], raw)
                native = json.loads(raw.read_text(encoding="utf-8"))
                native_cases = native.get("cases")
                if not isinstance(native_cases, list) or len(native_cases) != 1:
                    raise ValueError("single-case execution did not return exactly one result")
                value = validate_case(native_cases[0], identifier, semantic_hash, resource_class)
                cases[identifier] = value
                cache.store(args.cache_root, components(contract, identifier, semantic_hash, shared_evaluator), {"case_id": identifier, "semantic_input_hash": semantic_hash, "outcome": "passed", "result_hash": value["result_hash"]})
            for index, identifiers in enumerate(assignments):
                values = [cases[identifier] for identifier in identifiers]
                (args.output_dir / f"shard-{index}.json").write_bytes(canonical_bytes(report(contract, index, args.shard_count, identifiers, values)) + b"\n")
        if set(cases) != set(contract["case_ids"]):
            raise ValueError("cache execution did not cover the complete contract universe")
        observation = {"schema_version": "tracksmith-tutor-cache-observation/1", "mode": mode, "hits": len(contract["case_ids"]) - len(misses), "misses": len(misses), "case_ids_executed": misses, "case_ids_reused": sorted(set(contract["case_ids"]) - set(misses)), "binary_sha256_observational": digest(args.binary.read_bytes())}
        (args.output_dir / "cache-observation.json").write_bytes(canonical_bytes(observation) + b"\n")
        print(json.dumps(observation, sort_keys=True))
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"Tutor cache execution failed: {error}", file=sys.stderr); return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
