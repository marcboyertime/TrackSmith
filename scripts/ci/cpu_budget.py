#!/usr/bin/env python3
"""Conservative worker count for a single runner; never exceeds a caller cap."""
from __future__ import annotations
import argparse, os

MAX_TUTOR_WORKERS = 3

def budget(cap: int, reserve: int = 1) -> int:
    if type(cap) is not int or type(reserve) is not int or cap < 1 or cap > MAX_TUTOR_WORKERS or reserve < 0: raise ValueError("invalid CPU budget")
    logical = os.cpu_count() or 1
    return max(1, min(cap, max(1, logical - reserve)))

if __name__ == "__main__":
    parser = argparse.ArgumentParser(); parser.add_argument("--cap", type=int, default=3); parser.add_argument("--reserve", type=int, default=1)
    args = parser.parse_args(); print(budget(args.cap, args.reserve))
