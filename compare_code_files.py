#!/usr/bin/env python3
"""
compare_code_files.py
=====================
This utility scans multiple Dontpullup project directories (current working
copy, backups, music export, merged directory, and recovered files) and
systematically compares Swift files **by their actual code** instead of just
filenames.

Features
--------
1. Groups files with *identical* code using a SHA-256 hash (even if their
   relative paths differ) and writes the result to `duplicates_by_content.csv`.
2. Detects *conflicts* where files share the same relative path but have
   **different** code across locations and writes the result to
   `conflicts_by_path.csv`.
3. Prints human-readable summaries so you can quickly decide which files to
   inspect further with a diff tool (e.g., `opendiff` or `code --diff`).

Run the script from the workspace root:
    python3 compare_code_files.py
"""

import csv
import glob
import hashlib
import os
from collections import defaultdict
from typing import Dict, List, Tuple

# ---------------------------------------------------------------------------
# Configuration                                                               
# ---------------------------------------------------------------------------

# Update this list if you add/remove comparison roots
LOCATIONS: Dict[str, str] = {
    "current": "Dontpullup/Dontpullup",
    "backup": "Dontpullup/Dontpullup.bak",
    "music": "/Users/melfranklin/Music/Dontpullup/Dontpullup",
    "merged": "/Users/melfranklin/DontpullupMerged",
    "recovered": "/Users/melfranklin/DontpullupFix",
}

# Output CSV files
DUPLICATES_CSV = "duplicates_by_content.csv"
CONFLICTS_CSV = "conflicts_by_path.csv"

# ---------------------------------------------------------------------------
# Helpers                                                                     
# ---------------------------------------------------------------------------

def compute_sha256(file_path: str) -> str:
    """Return the SHA-256 hash for the given file (binary mode)."""
    hasher = hashlib.sha256()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def collect_swift_files() -> List[Tuple[str, str, str, str]]:
    """Return a list of tuples: (relative_path, location_key, abs_path, sha256)."""
    records = []
    cwd = os.getcwd()

    for loc_key, loc_root in LOCATIONS.items():
        # Expand to absolute path (respect absolute inputs)
        abs_root = loc_root if os.path.isabs(loc_root) else os.path.join(cwd, loc_root)
        if not os.path.isdir(abs_root):
            continue  # Skip missing locations silently
        pattern = os.path.join(abs_root, "**", "*.swift")
        for abs_path in glob.iglob(pattern, recursive=True):
            rel_path = os.path.relpath(abs_path, abs_root)
            try:
                sha = compute_sha256(abs_path)
            except Exception as exc:  # pragma: no cover
                print(f"[WARN] Could not hash {abs_path}: {exc}")
                continue
            records.append((rel_path, loc_key, abs_path, sha))
    return records


# ---------------------------------------------------------------------------
# Analysis                                                                    
# ---------------------------------------------------------------------------

def build_content_groups(records):
    """Group by file hash -> list of (rel_path, location, abs_path)."""
    by_hash: Dict[str, List[Tuple[str, str, str]]] = defaultdict(list)
    for rel_path, loc, abs_path, sha in records:
        by_hash[sha].append((rel_path, loc, abs_path))
    return {h: lst for h, lst in by_hash.items() if len(lst) > 1}


def build_conflict_groups(records):
    """Group by relative path -> list of (location, abs_path, sha) where >1 unique sha."""
    by_path: Dict[str, List[Tuple[str, str, str]]] = defaultdict(list)
    for rel_path, loc, abs_path, sha in records:
        by_path[rel_path].append((loc, abs_path, sha))
    # Keep only paths with differing hashes
    conflicts = {}
    for rel_path, items in by_path.items():
        unique_hashes = {sha for _, _, sha in items}
        if len(unique_hashes) > 1:
            conflicts[rel_path] = items
    return conflicts

# ---------------------------------------------------------------------------
# CSV Output                                                                  
# ---------------------------------------------------------------------------


def write_duplicates_csv(groups):
    """Write duplicates_by_content.csv with columns: hash, count, details..."""
    with open(DUPLICATES_CSV, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["sha256", "count", "details (rel_path | location)"])
        for sha, entries in sorted(groups.items(), key=lambda x: len(x[1]), reverse=True):
            detail = "; ".join(f"{rel} | {loc}" for rel, loc, _ in entries)
            writer.writerow([sha, len(entries), detail])


def write_conflicts_csv(conflicts):
    """Write conflicts_by_path.csv with columns: rel_path, location, sha256."""
    with open(CONFLICTS_CSV, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["rel_path", "location", "sha256"])
        for rel_path, entries in sorted(conflicts.items()):
            for loc, _, sha in entries:
                writer.writerow([rel_path, loc, sha])

# ---------------------------------------------------------------------------
# Main                                                                        
# ---------------------------------------------------------------------------


def main():
    print("Scanning Swift files across configured locations…")
    records = collect_swift_files()
    print(f"  Found {len(records)} Swift files total.")

    # 1. Duplicate groups by identical content
    dups = build_content_groups(records)
    print(f"  Identified {len(dups)} duplicate content groups (≥2 identical files).")

    # 2. Conflicts: same rel_path but differing content
    conflicts = build_conflict_groups(records)
    print(f"  Found {len(conflicts)} path conflicts where code differs across locations.")

    # Write CSV reports
    write_duplicates_csv(dups)
    write_conflicts_csv(conflicts)

    print("\nReports generated:")
    print(f"  • {DUPLICATES_CSV}")
    print(f"  • {CONFLICTS_CSV}")

    # Show quick summary of conflicts (first 10)
    if conflicts:
        print("\nSample conflicts (first 10):")
        for rel_path, entries in list(conflicts.items())[:10]:
            locs = ", ".join(f"{loc} ({sha[:6]})" for loc, _, sha in entries)
            print(f"  - {rel_path}: {locs}")

    # Guidance for next steps
    print("\nNext steps:")
    print("  1. Review `conflicts_by_path.csv` and decide which version to keep.")
    print("  2. Use a diff tool to inspect differences, e.g.:")
    print("       opendiff <path1> <path2>")
    print("       code --diff <path1> <path2>")
    print("  3. After resolving, you can run merge_files.py or copy files manually.")


if __name__ == "__main__":
    main() 