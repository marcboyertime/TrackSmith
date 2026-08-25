#!/usr/bin/env python3
"""Versioned, dependency-free primitives for deterministic local test sharding."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any

SCHEMA = "tracksmith-shard-report/1"
ALGORITHM = "lpt-cost-v1"
FALLBACK = "sha256-modulo-v1"


def digest(value: str | bytes) -> str:
    return hashlib.sha256(value.encode() if isinstance(value, str) else value).hexdigest()


def partition_hash(case_ids: list[str]) -> str:
    return digest("\n".join(sorted(case_ids)))


def assign(case_ids: list[str], shard_count: int, costs: dict[str, float] | None = None) -> tuple[list[list[str]], str]:
    if shard_count < 1:
        raise ValueError("shard_count must be positive")
    identifiers = sorted(set(case_ids))
    if len(identifiers) != len(case_ids) or any(not item for item in identifiers):
        raise ValueError("case IDs must be unique and nonempty")
    if identifiers and costs and all(item in costs and costs[item] > 0 for item in identifiers):
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
