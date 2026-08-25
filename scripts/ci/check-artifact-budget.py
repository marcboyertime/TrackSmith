#!/usr/bin/env python3
"""Fail closed before uploading compact, explicitly named CI evidence."""
from __future__ import annotations

import argparse
import os
import stat
import sys
from pathlib import Path

MAXIMUM_BYTES = 25 * 1024 * 1024


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("paths", nargs="+", type=Path)
    args = parser.parse_args()
    if len(args.paths) != len(set(args.paths)):
        print("artifact budget failed: duplicate path", file=sys.stderr); return 1
    total = 0
    for path in args.paths:
        try: entry = os.lstat(path)
        except OSError as error:
            print(f"artifact budget failed: unreadable {path}: {error}", file=sys.stderr); return 1
        if stat.S_ISLNK(entry.st_mode) or not stat.S_ISREG(entry.st_mode):
            print(f"artifact budget failed: {path} must be a regular non-symlink file", file=sys.stderr); return 1
        total += entry.st_size
        if total > MAXIMUM_BYTES:
            print(f"artifact budget failed: {total} bytes exceeds {MAXIMUM_BYTES}", file=sys.stderr); return 1
    print(f"artifact budget passed: {len(args.paths)} file(s), {total}/{MAXIMUM_BYTES} bytes")
    return 0


if __name__ == "__main__": raise SystemExit(main())
