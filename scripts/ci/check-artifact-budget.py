#!/usr/bin/env python3
"""Seal compact CI evidence into one bounded, immutable upload snapshot."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import stat
import sys
import zipfile
from pathlib import Path

MAXIMUM_BYTES = 25 * 1024 * 1024


def checked_bytes(path: Path) -> bytes:
    try: entry = os.lstat(path)
    except OSError as error: raise ValueError(f"unreadable {path}: {error}") from error
    if stat.S_ISLNK(entry.st_mode) or not stat.S_ISREG(entry.st_mode): raise ValueError(f"{path} must be a regular non-symlink file")
    if entry.st_size > MAXIMUM_BYTES: raise ValueError(f"{path} exceeds 25 MB bound")
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    try:
        opened = os.fstat(descriptor)
        if not stat.S_ISREG(opened.st_mode) or (opened.st_dev, opened.st_ino, opened.st_size) != (entry.st_dev, entry.st_ino, entry.st_size): raise ValueError(f"{path} changed while opening")
        parts: list[bytes] = []; remaining = entry.st_size
        while remaining:
            chunk = os.read(descriptor, min(remaining, 64 * 1024))
            if not chunk: raise ValueError(f"{path} truncated while reading")
            parts.append(chunk); remaining -= len(chunk)
        if os.read(descriptor, 1) or (opened.st_dev, opened.st_ino, opened.st_size) != (os.fstat(descriptor).st_dev, os.fstat(descriptor).st_ino, os.fstat(descriptor).st_size): raise ValueError(f"{path} changed while reading")
        return b"".join(parts)
    finally: os.close(descriptor)


def seal(output: Path, sources: list[Path]) -> int:
    if output.exists() or output.is_symlink(): raise ValueError(f"sealed output already exists: {output}")
    records = [(source.name, checked_bytes(source)) for source in sources]
    total = sum(len(data) for _, data in records)
    if total > MAXIMUM_BYTES: raise ValueError(f"inputs total {total} bytes exceeds {MAXIMUM_BYTES}")
    manifest = {"schema_version": "tracksmith-compact-artifact/1", "files": [{"name": name, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()} for name, data in records]}
    temporary = output.with_name(f".{output.name}.{os.getpid()}.tmp")
    output.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    try:
        with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9, strict_timestamps=True) as archive:
            for name, data in records:
                info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0)); info.compress_type = zipfile.ZIP_DEFLATED; info.external_attr = 0o600 << 16
                archive.writestr(info, data)
            info = zipfile.ZipInfo("artifact-manifest.json", date_time=(1980, 1, 1, 0, 0, 0)); info.compress_type = zipfile.ZIP_DEFLATED; info.external_attr = 0o600 << 16
            archive.writestr(info, (json.dumps(manifest, sort_keys=True, separators=(",", ":")) + "\n").encode())
        sealed = os.lstat(temporary)
        if stat.S_ISLNK(sealed.st_mode) or not stat.S_ISREG(sealed.st_mode) or sealed.st_size > MAXIMUM_BYTES: raise ValueError("sealed artifact is not a bounded regular file")
        os.replace(temporary, output)
        return sealed.st_size
    except BaseException:
        try: temporary.unlink()
        except FileNotFoundError: pass
        raise


def main() -> int:
    parser = argparse.ArgumentParser(); parser.add_argument("--seal-output", type=Path); parser.add_argument("paths", nargs="+", type=Path); args = parser.parse_args()
    if len(args.paths) != len(set(args.paths)):
        print("artifact budget failed: duplicate path", file=sys.stderr); return 1
    try:
        if args.seal_output is None:
            total = sum(len(checked_bytes(path)) for path in args.paths)
            if total > MAXIMUM_BYTES: raise ValueError(f"inputs total {total} bytes exceeds {MAXIMUM_BYTES}")
            count = len(args.paths)
        else: total = seal(args.seal_output, args.paths); count = 1
    except (OSError, ValueError) as error:
        print(f"artifact budget failed: {error}", file=sys.stderr); return 1
    print(f"artifact budget passed: {count} sealed file(s), {total}/{MAXIMUM_BYTES} bytes")
    return 0


if __name__ == "__main__": raise SystemExit(main())
