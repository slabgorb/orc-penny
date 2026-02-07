#!/usr/bin/env python3
"""
Migrate monolithic sprint YAML files to sharded per-epic format.

Splits current-sprint.yaml and future.yaml so each epic lives in its own
file (epic-{ID}.yaml) alongside the index. The index files become lean
references to epic IDs.

Usage:
    python sprint/migrate-to-shards.py              # Execute migration
    python sprint/migrate-to-shards.py --dry-run     # Preview only
    python sprint/migrate-to-shards.py --reassemble  # Reverse: shards → monolithic
"""

import argparse
import io
import os
import re
import shutil
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

from ruamel.yaml import YAML
from ruamel.yaml.comments import CommentedMap, CommentedSeq
from ruamel.yaml.scalarstring import LiteralScalarString


# ---------- YAML config (matches yaml_io.py) ----------

EPIC_KEY_ORDER = [
    "id", "type", "title", "description", "priority", "status",
    "repos", "jira", "points", "marker", "stories",
]

STORY_KEY_ORDER = [
    "id", "jira", "title", "description", "points", "priority",
    "status", "in_sprint", "assigned_to", "started", "repos",
    "workflow", "acceptance_criteria", "completed", "pr",
    "delivered_in", "notes",
]

SPRINT_KEY_ORDER = [
    "name", "jira_sprint_id", "jira_sprint_name", "goal",
    "start_date", "end_date", "status",
]

TOP_KEY_ORDER = ["sprint", "epics", "stories"]


def _make_yaml() -> YAML:
    yml = YAML()
    yml.preserve_quotes = True
    yml.default_flow_style = False
    yml.indent(mapping=2, sequence=4, offset=2)
    yml.width = 4096
    return yml


def _sort_mapping(data: CommentedMap, key_order: list[str]) -> CommentedMap:
    result = CommentedMap()
    for key in key_order:
        if key in data:
            result[key] = data[key]
    for key in data:
        if key not in key_order:
            result[key] = data[key]
    return result


def _ensure_block_scalars(data: Any) -> Any:
    if isinstance(data, CommentedMap):
        result = CommentedMap()
        for key, value in data.items():
            result[key] = _ensure_block_scalars(value)
        return result
    elif isinstance(data, (list, CommentedSeq)):
        result_list = CommentedSeq()
        for item in data:
            result_list.append(_ensure_block_scalars(item))
        return result_list
    elif isinstance(data, str) and "\n" in data:
        return LiteralScalarString(data)
    return data


def _canonicalize_epic(epic: Any) -> Any:
    """Apply canonical ordering to an epic and its stories."""
    if not isinstance(epic, CommentedMap):
        cm = CommentedMap()
        for k, v in epic.items():
            cm[k] = v
        epic = cm

    sorted_epic = _sort_mapping(epic, EPIC_KEY_ORDER)

    if "stories" in sorted_epic and isinstance(sorted_epic["stories"], (list, CommentedSeq)):
        new_stories = CommentedSeq()
        for story in sorted_epic["stories"]:
            if isinstance(story, (dict, CommentedMap)):
                story_cm = story if isinstance(story, CommentedMap) else CommentedMap(story)
                new_stories.append(_sort_mapping(story_cm, STORY_KEY_ORDER))
            else:
                new_stories.append(story)
        sorted_epic["stories"] = new_stories

    return _ensure_block_scalars(sorted_epic)


def _dump_yaml(data: Any) -> str:
    yml = _make_yaml()
    stream = io.StringIO()
    yml.dump(data, stream)
    output = stream.getvalue()
    lines = [line.rstrip() for line in output.split("\n")]
    return "\n".join(lines).rstrip("\n") + "\n"


def _atomic_write(path: Path, content: str) -> None:
    tmp_path = path.with_suffix(".yaml.tmp")
    try:
        with open(tmp_path, "w") as f:
            f.write(content)
        os.replace(tmp_path, path)
    except Exception:
        if tmp_path.exists():
            tmp_path.unlink()
        raise


def _read_yaml(path: Path) -> Any:
    yml = _make_yaml()
    with open(path) as f:
        data = yml.load(f)
    if data is None:
        raise ValueError(f"Empty YAML file: {path}")
    return data


# ---------- Epic ID / filename logic ----------

JIRA_PATTERN = re.compile(r"^MSSCI-\d{5}$")


def _get_epic_ref(epic: dict) -> str:
    """Get the canonical reference ID for an epic (used in index lists).

    Always prefer Jira key. Fall back to short ID.
    """
    jira = epic.get("jira")
    epic_id = str(epic.get("id", ""))

    if jira and JIRA_PATTERN.match(str(jira)):
        return str(jira)
    if JIRA_PATTERN.match(epic_id):
        return epic_id
    return epic_id


def _get_epic_filename(epic: dict) -> str:
    """Derive filename for an epic shard file."""
    ref = _get_epic_ref(epic)
    return f"epic-{ref}.yaml"


# ---------- Sharding ----------

def _count_stories(epics: list) -> int:
    total = 0
    for epic in epics:
        if isinstance(epic, (dict, CommentedMap)):
            stories = epic.get("stories", [])
            total += len(stories) if stories else 0
    return total


def shard_current_sprint(sprint_dir: Path, data: Any, dry_run: bool) -> list[str]:
    """Shard current-sprint.yaml. Returns list of created filenames."""
    epics = data.get("epics", [])
    if not epics:
        print("  No epics found in current-sprint.yaml")
        return []

    # Check if already sharded (epics is list of strings)
    if epics and isinstance(epics[0], str):
        print("  current-sprint.yaml is already sharded")
        return []

    created = []
    epic_refs = CommentedSeq()

    for i, epic in enumerate(epics):
        epic_id = epic.get("id")
        if not epic_id:
            print(f"  ERROR: Epic at index {i} has no id field, skipping")
            continue

        filename = _get_epic_filename(epic)
        filepath = sprint_dir / filename
        ref = _get_epic_ref(epic)
        epic_refs.append(ref)

        if dry_run:
            stories = epic.get("stories", [])
            story_count = len(stories) if stories else 0
            print(f"  [dry-run] Would write {filename} ({story_count} stories)")
        else:
            canonicalized = _canonicalize_epic(epic)
            content = _dump_yaml(canonicalized)
            _atomic_write(filepath, content)
            stories = epic.get("stories", [])
            story_count = len(stories) if stories else 0
            print(f"  + {filename} ({story_count} stories)")
            created.append(filename)

    # Build index
    index = CommentedMap()
    index["sprint"] = data["sprint"]
    index["epics"] = epic_refs

    # Preserve orphan stories
    if "stories" in data and data["stories"]:
        index["stories"] = data["stories"]

    if dry_run:
        print(f"  [dry-run] Would update current-sprint.yaml (index with {len(epic_refs)} epic refs)")
    else:
        # Canonicalize sprint section
        if isinstance(index["sprint"], (dict, CommentedMap)):
            sprint_cm = index["sprint"] if isinstance(index["sprint"], CommentedMap) else CommentedMap(index["sprint"])
            index["sprint"] = _sort_mapping(sprint_cm, SPRINT_KEY_ORDER)

        # Canonicalize orphan stories
        if "stories" in index:
            index["stories"] = _ensure_block_scalars(index["stories"])

        content = _dump_yaml(index)
        _atomic_write(sprint_dir / "current-sprint.yaml", content)
        print(f"  * current-sprint.yaml (index with {len(epic_refs)} epic refs)")

    return created


def shard_future(sprint_dir: Path, data: Any, dry_run: bool) -> list[str]:
    """Shard future.yaml. Returns list of created filenames."""
    future = data.get("future", {})
    initiatives = future.get("initiatives", [])
    if not initiatives:
        print("  No initiatives found in future.yaml")
        return []

    # Check if already sharded
    for init in initiatives:
        epics = init.get("epics", [])
        if epics and isinstance(epics[0], str):
            print("  future.yaml is already sharded")
            return []
        break  # Only check first initiative

    created = []

    for init in initiatives:
        init_name = init.get("name", "Unknown")
        epics = init.get("epics", [])

        if not epics:
            continue

        epic_refs = CommentedSeq()

        for i, epic in enumerate(epics):
            epic_id = epic.get("id")
            if not epic_id:
                print(f"  ERROR: Epic at index {i} in '{init_name}' has no id, skipping")
                continue

            filename = _get_epic_filename(epic)
            filepath = sprint_dir / filename
            ref = _get_epic_ref(epic)
            epic_refs.append(ref)

            if dry_run:
                stories = epic.get("stories", [])
                story_count = len(stories) if stories else 0
                print(f"  [dry-run] Would write {filename} ({story_count} stories)")
            else:
                canonicalized = _canonicalize_epic(epic)
                content = _dump_yaml(canonicalized)
                _atomic_write(filepath, content)
                stories = epic.get("stories", [])
                story_count = len(stories) if stories else 0
                print(f"  + {filename} ({story_count} stories)")
                created.append(filename)

        # Replace epic objects with refs in initiative
        init["epics"] = epic_refs

    if dry_run:
        print(f"  [dry-run] Would update future.yaml (index)")
    else:
        content = _dump_yaml(_ensure_block_scalars(data))
        _atomic_write(sprint_dir / "future.yaml", content)
        print(f"  * future.yaml (index)")

    return created


# ---------- Reassembly ----------

def reassemble(sprint_dir: Path, dry_run: bool) -> None:
    """Reassemble sharded epics back into monolithic files."""
    sprint_path = sprint_dir / "current-sprint.yaml"
    future_path = sprint_dir / "future.yaml"

    # Reassemble current-sprint.yaml
    if sprint_path.exists():
        data = _read_yaml(sprint_path)
        epics = data.get("epics", [])

        if epics and isinstance(epics[0], str):
            print("\nReassembling current-sprint.yaml...")
            full_epics = CommentedSeq()

            for ref in epics:
                epic_file = sprint_dir / f"epic-{ref}.yaml"
                if not epic_file.exists():
                    print(f"  ERROR: Missing epic file: {epic_file}")
                    sys.exit(1)

                epic_data = _read_yaml(epic_file)
                full_epics.append(_canonicalize_epic(epic_data))
                print(f"  < {epic_file.name}")

            data["epics"] = full_epics

            if dry_run:
                print(f"  [dry-run] Would write reassembled current-sprint.yaml")
            else:
                # Re-canonicalize sprint section
                if isinstance(data["sprint"], (dict, CommentedMap)):
                    sprint_cm = data["sprint"] if isinstance(data["sprint"], CommentedMap) else CommentedMap(data["sprint"])
                    data["sprint"] = _sort_mapping(sprint_cm, SPRINT_KEY_ORDER)
                data = _ensure_block_scalars(data)
                content = _dump_yaml(data)
                _atomic_write(sprint_path, content)
                print(f"  * current-sprint.yaml (reassembled)")
        else:
            print("  current-sprint.yaml is not sharded, skipping")

    # Reassemble future.yaml
    if future_path.exists():
        data = _read_yaml(future_path)
        initiatives = data.get("future", {}).get("initiatives", [])
        any_sharded = False

        for init in initiatives:
            epics = init.get("epics", [])
            if epics and isinstance(epics[0], str):
                any_sharded = True
                break

        if any_sharded:
            print("\nReassembling future.yaml...")
            for init in initiatives:
                epics = init.get("epics", [])
                if not epics or not isinstance(epics[0], str):
                    continue

                full_epics = CommentedSeq()
                for ref in epics:
                    epic_file = sprint_dir / f"epic-{ref}.yaml"
                    if not epic_file.exists():
                        print(f"  ERROR: Missing epic file: {epic_file}")
                        sys.exit(1)

                    epic_data = _read_yaml(epic_file)
                    full_epics.append(_canonicalize_epic(epic_data))
                    print(f"  < {epic_file.name}")

                init["epics"] = full_epics

            if dry_run:
                print(f"  [dry-run] Would write reassembled future.yaml")
            else:
                data = _ensure_block_scalars(data)
                content = _dump_yaml(data)
                _atomic_write(future_path, content)
                print(f"  * future.yaml (reassembled)")
        else:
            print("  future.yaml is not sharded, skipping")

    # Clean up epic files after reassembly
    if not dry_run:
        epic_files = sorted(sprint_dir.glob("epic-*.yaml"))
        if epic_files:
            print(f"\nRemoving {len(epic_files)} epic shard files...")
            for ef in epic_files:
                ef.unlink()
                print(f"  - {ef.name}")


# ---------- Validation ----------

def validate_migration(sprint_dir: Path) -> bool:
    """Validate that migration produced consistent results."""
    sprint_path = sprint_dir / "current-sprint.yaml"
    future_path = sprint_dir / "future.yaml"
    errors = []

    # Check current-sprint index
    if sprint_path.exists():
        data = _read_yaml(sprint_path)
        epics = data.get("epics", [])

        if not epics:
            errors.append("current-sprint.yaml has no epics")
        elif not isinstance(epics[0], str):
            errors.append("current-sprint.yaml epics are not sharded (still objects)")
        else:
            for ref in epics:
                epic_file = sprint_dir / f"epic-{ref}.yaml"
                if not epic_file.exists():
                    errors.append(f"Missing epic file for ref '{ref}': {epic_file}")
                else:
                    try:
                        _read_yaml(epic_file)
                    except Exception as e:
                        errors.append(f"Invalid YAML in {epic_file.name}: {e}")

    # Check future index
    if future_path.exists():
        data = _read_yaml(future_path)
        initiatives = data.get("future", {}).get("initiatives", [])

        for init in initiatives:
            init_name = init.get("name", "Unknown")
            epics = init.get("epics", [])

            if not epics:
                continue

            if not isinstance(epics[0], str):
                errors.append(f"Initiative '{init_name}' epics are not sharded")
                continue

            for ref in epics:
                epic_file = sprint_dir / f"epic-{ref}.yaml"
                if not epic_file.exists():
                    errors.append(f"Missing epic file for ref '{ref}' in '{init_name}'")

    if errors:
        print("\nValidation FAILED:")
        for e in errors:
            print(f"  x {e}")
        return False

    # Count epic files
    epic_files = sorted(sprint_dir.glob("epic-*.yaml"))
    print(f"\nValidation passed: {len(epic_files)} epic files present")
    return True


# ---------- Main ----------

def main():
    parser = argparse.ArgumentParser(
        description="Migrate sprint YAML to sharded per-epic format"
    )
    parser.add_argument("--dry-run", action="store_true",
                        help="Preview changes without modifying files")
    parser.add_argument("--skip-backup", action="store_true",
                        help="Skip backup creation")
    parser.add_argument("--force", action="store_true",
                        help="Overwrite existing epic files")
    parser.add_argument("--reassemble", action="store_true",
                        help="Reverse: reassemble sharded epics into monolithic files")
    parser.add_argument("--validate", action="store_true",
                        help="Validate existing migration")
    args = parser.parse_args()

    sprint_dir = Path(__file__).parent
    sprint_path = sprint_dir / "current-sprint.yaml"
    future_path = sprint_dir / "future.yaml"

    if args.validate:
        ok = validate_migration(sprint_dir)
        sys.exit(0 if ok else 1)

    if args.reassemble:
        print("Reassembling sharded YAML back to monolithic...")
        reassemble(sprint_dir, args.dry_run)
        if not args.dry_run:
            print("\nDone. Epic shard files removed.")
        return

    # --- Forward migration ---
    print("Sprint YAML Sharding Migration")
    print("=" * 40)

    # Pre-flight: check source files exist
    if not sprint_path.exists():
        print(f"ERROR: {sprint_path} not found")
        sys.exit(1)
    if not future_path.exists():
        print(f"ERROR: {future_path} not found")
        sys.exit(1)

    # Check for existing epic files
    existing = sorted(sprint_dir.glob("epic-*.yaml"))
    if existing and not args.force:
        print(f"\nFound {len(existing)} existing epic files:")
        for ef in existing:
            print(f"  {ef.name}")
        print("\nUse --force to overwrite, or --reassemble to reverse first.")
        sys.exit(1)

    # Read source files
    current_data = _read_yaml(sprint_path)
    future_data = _read_yaml(future_path)

    # Check for ID collisions between files
    current_refs = set()
    for epic in current_data.get("epics", []):
        if isinstance(epic, (dict, CommentedMap)):
            current_refs.add(_get_epic_ref(epic))

    future_refs = set()
    for init in future_data.get("future", {}).get("initiatives", []):
        for epic in init.get("epics", []):
            if isinstance(epic, (dict, CommentedMap)):
                future_refs.add(_get_epic_ref(epic))

    collisions = current_refs & future_refs
    if collisions:
        print(f"\nERROR: Epic ID collision between current and future: {collisions}")
        sys.exit(1)

    # Count stories before migration
    current_epics = current_data.get("epics", [])
    future_epics = []
    for init in future_data.get("future", {}).get("initiatives", []):
        future_epics.extend(init.get("epics", []))

    stories_before = _count_stories(current_epics) + _count_stories(future_epics)
    orphan_count = len(current_data.get("stories", []))

    # Backup
    if not args.dry_run and not args.skip_backup:
        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        backup_dir = sprint_dir / f".migration-backup-{timestamp}"
        backup_dir.mkdir(exist_ok=True)
        shutil.copy2(sprint_path, backup_dir / "current-sprint.yaml")
        shutil.copy2(future_path, backup_dir / "future.yaml")
        print(f"\nBackup: {backup_dir.name}/")

    # Shard current-sprint.yaml
    print(f"\ncurrent-sprint.yaml ({len(current_epics)} epics, {orphan_count} orphan stories):")
    current_created = shard_current_sprint(sprint_dir, current_data, args.dry_run)

    # Shard future.yaml
    init_count = len(future_data.get("future", {}).get("initiatives", []))
    print(f"\nfuture.yaml ({init_count} initiatives, {len(future_epics)} epics):")
    future_created = shard_future(sprint_dir, future_data, args.dry_run)

    # Summary
    total_created = len(current_created) + len(future_created)
    print(f"\n{'=' * 40}")

    if args.dry_run:
        total_would = len(current_epics) + len(future_epics)
        print(f"Dry run complete. Would create {total_would} epic files.")
    else:
        print(f"Created {total_created} epic files, {stories_before} stories preserved.")

        # Post-migration validation
        ok = validate_migration(sprint_dir)
        if not ok:
            print("\nWARNING: Post-migration validation failed!")
            sys.exit(1)


if __name__ == "__main__":
    main()
