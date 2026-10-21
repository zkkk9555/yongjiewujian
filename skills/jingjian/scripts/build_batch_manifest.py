from __future__ import annotations

import argparse
import hashlib
import json
import os
from datetime import datetime, timezone
from pathlib import Path


VIDEO_EXTENSIONS = {".mp4", ".mov", ".mkv", ".ts", ".m2ts", ".avi", ".webm"}

SAMPLE_BLOCKS = 3
SAMPLE_BYTES = 1 << 20


def content_fingerprint(path: Path, size: int) -> str:
    """Sampled content hash: head/middle/tail blocks plus size.

    The key must not embed the absolute path: rename/move/copy of the same
    bytes keeps the same fingerprint. Full reads of multi-GB 4K60 sources
    are avoided by sampling; size disambiguates short-head collisions.
    """
    digest = hashlib.sha256()
    digest.update(f"size={size}".encode("utf-8"))
    if size <= 0:
        return digest.hexdigest()[:16]
    try:
        with path.open("rb") as handle:
            positions = [0]
            if size > SAMPLE_BYTES:
                positions.append(max(0, size // 2 - SAMPLE_BYTES // 2))
                positions.append(max(0, size - SAMPLE_BYTES))
            for position in dict.fromkeys(positions):
                handle.seek(position)
                digest.update(handle.read(SAMPLE_BYTES))
    except OSError:
        digest.update(b"unreadable")
    return digest.hexdigest()[:16]


def stable_id(path: Path, size: int, mtime_ns: int) -> str:
    payload = f"{content_fingerprint(path, size)}|{size}".encode("utf-8", "surrogatepass")
    return hashlib.sha1(payload).hexdigest()[:16]


def collect_files(inputs: list[Path], recursive: bool) -> tuple[list[Path], list[dict]]:
    files: dict[str, Path] = {}
    errors: list[dict] = []
    for raw in inputs:
        path = raw.expanduser()
        if not path.exists():
            errors.append({"path": str(path), "error": "missing"})
            continue
        if path.is_file():
            candidates = [path]
        elif recursive:
            candidates = [item for item in path.rglob("*") if item.is_file()]
        else:
            candidates = [item for item in path.iterdir() if item.is_file()]
        for item in candidates:
            if item.suffix.lower() not in VIDEO_EXTENSIONS:
                continue
            resolved = item.resolve()
            files[os.path.normcase(str(resolved))] = resolved
    return sorted(files.values(), key=lambda value: str(value).lower()), errors


def make_entry(path: Path) -> dict:
    stat = path.stat()
    return {
        "id": stable_id(path, stat.st_size, stat.st_mtime_ns),
        "content_fingerprint": content_fingerprint(path, stat.st_size),
        "path": str(path),
        "filename": path.name,
        "extension": path.suffix.lower(),
        "size_bytes": stat.st_size,
        "modified_at": datetime.fromtimestamp(stat.st_mtime, tz=timezone.utc).isoformat(),
        "status": "pending_probe",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Build a deterministic batch manifest for Naraka video inputs.")
    parser.add_argument("inputs", nargs="+", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--no-recursive", action="store_true")
    args = parser.parse_args()

    files, errors = collect_files(args.inputs, recursive=not args.no_recursive)
    manifest = {
        "schema": "naraka-highlight-batch/v1",
        "created_at": datetime.now(timezone.utc).isoformat(),
        "recursive": not args.no_recursive,
        "inputs": [str(path.expanduser()) for path in args.inputs],
        "sources": [make_entry(path) for path in files],
        "errors": errors,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"sources": len(files), "errors": len(errors), "output": str(args.output)}, ensure_ascii=False))
    return 0 if files and not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
