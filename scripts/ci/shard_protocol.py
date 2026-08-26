#!/usr/bin/env python3
"""Versioned, dependency-free primitives for deterministic local test sharding."""
from __future__ import annotations

import hashlib
import json
import math
import re
import sys
from pathlib import Path
from typing import Any

SCHEMA = "tracksmith-shard-report/1"
ALGORITHM = "lpt-cost-v1"
FALLBACK = "sha256-modulo-v1"
COST_SCHEMA = "tracksmith-tutor-test-costs/2"
CONTRACT_SCHEMA = "tracksmith-tutor-shard-contract/1"
SHA256 = re.compile(r"^[0-9a-f]{64}$")
COST_FIELDS = {"schema_version", "suite_id", "suite_version", "suite_source_hash", "policy_hash", "index_hash", "case_ids", "cost_seconds"}
CONTRACT_FIELDS = {"schema_version", "suite_id", "suite_version", "suite_source_hash", "policy_hash", "index_hash", "case_ids", "commit", "tree_classification", "toolchain_identity", "toolchain_hash"}


def digest(value: str | bytes) -> str:
    return hashlib.sha256(value.encode() if isinstance(value, str) else value).hexdigest()


def partition_hash(case_ids: list[str]) -> str:
    return digest("\n".join(sorted(case_ids)))


def assign(case_ids: list[str], shard_count: int, costs: dict[str, float] | None = None) -> tuple[list[list[str]], str]:
    if type(shard_count) is not int or shard_count < 1:
        raise ValueError("shard_count must be positive")
    if not isinstance(case_ids, list) or any(not isinstance(item, str) for item in case_ids):
        raise ValueError("case IDs must be a string list")
    if costs is not None and (not isinstance(costs, dict) or any(not isinstance(item, str) for item in costs)):
        raise ValueError("costs must use string case IDs")
    identifiers = sorted(set(case_ids))
    if len(identifiers) != len(case_ids) or any(not item for item in identifiers):
        raise ValueError("case IDs must be unique and nonempty")
    if identifiers and costs and all(item in costs and type(costs[item]) in (int, float) and math.isfinite(costs[item]) and costs[item] > 0 for item in identifiers):
        bins: list[tuple[float, list[str]]] = [(0.0, []) for _ in range(shard_count)]
        for item in sorted(identifiers, key=lambda candidate: (-costs[candidate], candidate)):
            index = min(range(shard_count), key=lambda candidate: (bins[candidate][0], candidate))
            load, values = bins[index]
            bins[index] = (load + costs[item], values + [item])
        return [sorted(values) for _, values in bins], ALGORITHM
    bins = [[] for _ in range(shard_count)]
    for item in identifiers:
        bins[int(digest(item)[:16], 16) % shard_count].append(item)
    return bins, FALLBACK


def read_json(path: Path) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"{path}: expected object")
    return data


def canonical_bytes(payload: dict[str, Any]) -> bytes:
    return json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode()


def _file_hash(root: Path, relative: str) -> str:
    return digest((root / relative).read_bytes())


def load_cost_manifest(path: Path, root: Path) -> dict[str, Any]:
    value = read_json(path)
    if set(value) != COST_FIELDS or value.get("schema_version") != COST_SCHEMA:
        raise ValueError("cost manifest must use the exact versioned schema")
    if any(not isinstance(value.get(field), str) or not value[field] for field in ("suite_id", "suite_version")):
        raise ValueError("cost manifest suite identity is invalid")
    if any(not isinstance(value.get(field), str) or not SHA256.fullmatch(value[field]) for field in ("suite_source_hash", "policy_hash", "index_hash")):
        raise ValueError("cost manifest hashes are invalid")
    ids, costs = value.get("case_ids"), value.get("cost_seconds")
    if not isinstance(ids, list) or len(ids) != len(set(ids)) or any(not isinstance(item, str) or not item for item in ids):
        raise ValueError("cost manifest case universe must be a unique nonempty string list")
    if not isinstance(costs, dict) or set(costs) != set(ids) or any(not isinstance(item, str) or type(cost) not in (int, float) or not math.isfinite(cost) or cost <= 0 for item, cost in costs.items()):
        raise ValueError("cost manifest costs must exactly bind positive numeric case IDs")
    expected_hashes = {
        "suite_source_hash": _file_hash(root, "tools/TutorConversationTests/Sources/TutorConversationTests/TutorConversationTests.swift"),
        "policy_hash": _file_hash(root, "ci/tracksmith_compute_lanes.json"),
        "index_hash": _file_hash(root, "packages/ProductionTutor/Sources/ProductionTutor/Resources/CandidateRetrieval.manifest.json"),
    }
    if any(value[field] != expected for field, expected in expected_hashes.items()):
        raise ValueError("cost manifest is stale for the current suite/policy/index")
    return value


def build_contract(manifest_path: Path, root: Path, list_path: Path, commit: str, tree_classification: str, toolchain_identity: str) -> dict[str, Any]:
    manifest = load_cost_manifest(manifest_path, root)
    listed = [line.split("\t", 1)[0] for line in list_path.read_text(encoding="utf-8").splitlines()]
    if listed != manifest["case_ids"]:
        raise ValueError("release binary test universe does not exactly match the validated cost manifest")
    if not isinstance(commit, str) or not commit or (commit != "local" and not re.fullmatch(r"[0-9a-f]{40}", commit)):
        raise ValueError("contract commit must be local or a full SHA")
    if tree_classification not in {"local-observational", "github-clean-checkout"}:
        raise ValueError("contract tree classification is invalid")
    if not isinstance(toolchain_identity, str) or not toolchain_identity:
        raise ValueError("contract toolchain identity is invalid")
    return {
        "schema_version": CONTRACT_SCHEMA,
        "suite_id": manifest["suite_id"], "suite_version": manifest["suite_version"],
        "suite_source_hash": manifest["suite_source_hash"], "policy_hash": manifest["policy_hash"], "index_hash": manifest["index_hash"],
        "case_ids": manifest["case_ids"], "commit": commit, "tree_classification": tree_classification,
        "toolchain_identity": toolchain_identity, "toolchain_hash": digest(toolchain_identity),
    }


def validate_contract(value: dict[str, Any]) -> dict[str, Any]:
    if set(value) != CONTRACT_FIELDS or value.get("schema_version") != CONTRACT_SCHEMA:
        raise ValueError("shard contract must use the exact versioned schema")
    if any(not isinstance(value.get(field), str) or not value[field] for field in ("suite_id", "suite_version", "commit", "tree_classification", "toolchain_identity")) or any(not isinstance(value.get(field), str) or not SHA256.fullmatch(value[field]) for field in ("suite_source_hash", "policy_hash", "index_hash", "toolchain_hash")):
        raise ValueError("shard contract identities are invalid")
    ids = value.get("case_ids")
    if not isinstance(ids, list) or not ids or len(ids) != len(set(ids)) or any(not isinstance(item, str) or not item for item in ids):
        raise ValueError("shard contract universe is invalid")
    if value["commit"] != "local" and not re.fullmatch(r"[0-9a-f]{40}", value["commit"]):
        raise ValueError("shard contract commit is invalid")
    if value["tree_classification"] not in {"local-observational", "github-clean-checkout"}:
        raise ValueError("shard contract tree classification is invalid")
    if value["toolchain_hash"] != digest(value["toolchain_identity"]):
        raise ValueError("shard contract toolchain hash is invalid")
    return value


def load_contract(path: Path) -> dict[str, Any]:
    return validate_contract(read_json(path))


def main() -> int:
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--contract-output", type=Path)
    parser.add_argument("--cost-manifest", type=Path)
    parser.add_argument("--list", type=Path)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--commit")
    parser.add_argument("--tree-classification")
    parser.add_argument("--toolchain-identity")
    args = parser.parse_args()
    if not args.contract_output:
        parser.error("--contract-output is required")
    try:
        contract = build_contract(args.cost_manifest, args.repo_root, args.list, args.commit, args.tree_classification, args.toolchain_identity)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"shard contract failed: {error}", file=sys.stderr); return 1
    args.contract_output.write_bytes(canonical_bytes(contract) + b"\n")
    return 0


if __name__ == "__main__": raise SystemExit(main())
