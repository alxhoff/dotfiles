#!/usr/bin/env python3
"""Repair Cursor chat history after migration or opening Cursor too early.

Problems this fixes:
1. Duplicate workspaceStorage IDs for the same folder (old restored ID vs new empty ID).
2. Split history when a folder moved and a symlink keeps the old path (e.g.
   kernels/cartken_5_1_5 -> storage/kernels/cartken_5_1_5).
3. New Cursor Glass UI grouping many unrelated chats into a handful of projects.
4. Composer headers not marked visible in the agent sidebar (hasBeenInSidebar).
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import sqlite3
import sys
from collections import defaultdict
from pathlib import Path


def read_json(path: Path) -> dict | list | None:
    try:
        with path.open(encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, json.JSONDecodeError):
        return None


def write_json(path: Path, data: object, dry_run: bool) -> None:
    if dry_run:
        return
    with path.open("w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=4)
        fh.write("\n")


def folder_uri_to_path(folder_uri: str) -> Path | None:
    if not folder_uri.startswith("file://"):
        return None
    path = Path(folder_uri.removeprefix("file://"))
    if not path.exists():
        return path
    try:
        return path.resolve()
    except OSError:
        return path


def folder_group_score(
    entries: list[tuple[str, Path]],
    composers: list,
    backup_ws_root: Path | None,
) -> int:
    return sum(
        score_workspace(
            ws_id,
            ws_dir,
            backup_ws_root / ws_id if backup_ws_root else None,
            composers,
        )
        for ws_id, ws_dir in entries
    )


def merge_groups_by_realpath(
    groups: dict[str, list[tuple[str, Path]]],
    composers: list,
    backup_ws_root: Path | None,
) -> tuple[dict[str, list[tuple[str, Path]]], dict[str, str]]:
    """Merge workspace groups whose folder URIs resolve to the same directory."""
    real_to_uris: dict[Path, list[str]] = defaultdict(list)
    unresolved: dict[str, list[tuple[str, Path]]] = {}

    for folder_uri, entries in groups.items():
        real = folder_uri_to_path(folder_uri)
        if real is None:
            unresolved[folder_uri] = entries
        else:
            real_to_uris[real].append(folder_uri)

    merged: dict[str, list[tuple[str, Path]]] = dict(unresolved)
    folder_uri_alias: dict[str, str] = {}

    for real, uris in real_to_uris.items():
        if len(uris) == 1:
            merged[uris[0]] = list(groups[uris[0]])
            continue

        def uri_rank(uri: str) -> tuple[int, int, int]:
            score = folder_group_score(groups[uri], composers, backup_ws_root)
            opened = Path(uri.removeprefix("file://"))
            prefers_open_path = int(opened.exists() and opened != real)
            return (score, prefers_open_path, -len(uri))

        canonical_uri = max(uris, key=uri_rank)
        merged[canonical_uri] = []
        for uri in uris:
            merged[canonical_uri].extend(groups[uri])
            if uri != canonical_uri:
                folder_uri_alias[uri] = canonical_uri

    return merged, folder_uri_alias


def workspace_folder_key(workspace_json: Path) -> str | None:
    data = read_json(workspace_json)
    if not isinstance(data, dict):
        return None
    folder = data.get("folder")
    if isinstance(folder, str) and folder.startswith("file://"):
        return folder
    workspace = data.get("workspace")
    if isinstance(workspace, str) and workspace.startswith("file://"):
        return workspace
    return None


def db_bytes(ws_dir: Path) -> int:
    """Main DB file only — WAL/SHM are transient and inflate empty workspaces."""
    path = ws_dir / "state.vscdb"
    if path.is_file() and not path.is_symlink():
        return path.stat().st_size
    return 0


def workspace_composer_score(ws_dir: Path) -> int:
    """Prefer workspaces whose local composer.composerData has real chat history."""
    db = ws_dir / "state.vscdb"
    if not db.is_file():
        return 0
    conn = sqlite3.connect(db)
    try:
        row = conn.execute(
            "SELECT value FROM ItemTable WHERE key = 'composer.composerData'"
        ).fetchone()
        if not row:
            return 0
        try:
            data = json.loads(row[0])
        except json.JSONDecodeError:
            return len(row[0])
        composers = data.get("allComposers", [])
        if not isinstance(composers, list):
            return len(row[0])
        score = len(row[0])
        for composer in composers:
            if not isinstance(composer, dict) or composer.get("type") != "head":
                continue
            if composer.get("name") or composer.get("isArchived"):
                score += 50_000
        return score
    except sqlite3.Error:
        return 0
    finally:
        conn.close()


def composer_count(ws_id: str, composers: list) -> int:
    return sum(
        1
        for c in composers
        if isinstance(c, dict)
        and c.get("workspaceIdentifier", {}).get("id") == ws_id
    )


def score_workspace(
    ws_id: str,
    ws_dir: Path,
    backup_ws_dir: Path | None,
    composers: list,
) -> int:
    # Local workspace DB is authoritative; global headers get repointed after
    # opening a folder once and would otherwise pick the empty duplicate.
    score = workspace_composer_score(ws_dir) * 100
    score += composer_count(ws_id, composers) * 1_000
    score += db_bytes(ws_dir)
    if backup_ws_dir and backup_ws_dir.is_dir():
        score += 1_000_000
    return score


def load_global_value(global_db: Path, key: str):
    conn = sqlite3.connect(global_db)
    try:
        row = conn.execute("SELECT value FROM ItemTable WHERE key = ?", (key,)).fetchone()
        return json.loads(row[0]) if row else None
    except (sqlite3.Error, json.JSONDecodeError):
        return None
    finally:
        conn.close()


def save_global_value(global_db: Path, key: str, value, dry_run: bool) -> bool:
    payload = json.dumps(value, separators=(",", ":"))
    if dry_run:
        return True
    conn = sqlite3.connect(global_db)
    try:
        conn.execute(
            "INSERT INTO ItemTable(key, value) VALUES(?, ?) "
            "ON CONFLICT(key) DO UPDATE SET value = excluded.value",
            (key, payload),
        )
        conn.commit()
        return True
    except sqlite3.Error:
        return False
    finally:
        conn.close()


def load_composers(global_db: Path) -> list:
    data = load_global_value(global_db, "composer.composerHeaders")
    if isinstance(data, dict):
        composers = data.get("allComposers", [])
        return composers if isinstance(composers, list) else []
    return []


def save_composers(global_db: Path, composers: list, dry_run: bool) -> bool:
    data = load_global_value(global_db, "composer.composerHeaders")
    if not isinstance(data, dict):
        return False
    data["allComposers"] = composers
    return save_global_value(global_db, "composer.composerHeaders", data, dry_run)


def composer_folder_uri(composer: dict) -> str | None:
    ws = composer.get("workspaceIdentifier")
    if not isinstance(ws, dict):
        return None
    uri = ws.get("uri")
    if isinstance(uri, dict):
        fs_path = uri.get("fsPath")
        if isinstance(fs_path, str) and fs_path:
            return f"file://{fs_path}"
    folder = ws.get("folder")
    if isinstance(folder, str) and folder.startswith("file://"):
        return folder
    return None


def load_workspace_composers(ws_dir: Path) -> list:
    db = ws_dir / "state.vscdb"
    if not db.is_file():
        return []
    conn = sqlite3.connect(db)
    try:
        row = conn.execute(
            "SELECT value FROM ItemTable WHERE key = 'composer.composerData'"
        ).fetchone()
        if not row:
            return []
        data = json.loads(row[0])
        composers = data.get("allComposers", [])
        return composers if isinstance(composers, list) else []
    except (sqlite3.Error, json.JSONDecodeError):
        return []
    finally:
        conn.close()


def resolve_ws_dir(ws_root: Path, ws_id: str) -> Path:
    ws_dir = ws_root / ws_id
    if ws_dir.is_symlink():
        target = os.readlink(ws_dir)
        target_path = Path(target)
        ws_dir = target_path if target_path.is_absolute() else ws_root / target
    return ws_dir


def build_composer_folder_index(
    ws_root: Path, canonical_for_folder: dict[str, str]
) -> dict[str, tuple[str, str]]:
    """Map composerId -> (folder_uri, canonical workspace id) from local workspace DBs."""
    index: dict[str, tuple[str, str]] = {}
    for folder_uri, ws_id in canonical_for_folder.items():
        if not folder_uri.startswith("file://"):
            continue
        if "/.config/Cursor/Workspaces/" in folder_uri:
            continue
        ws_dir = resolve_ws_dir(ws_root, ws_id)
        for composer in load_workspace_composers(ws_dir):
            if not isinstance(composer, dict):
                continue
            composer_id = composer.get("composerId")
            if isinstance(composer_id, str) and composer_id:
                index[composer_id] = (folder_uri, ws_id)
    return index


def orphan_workspace_ids(ws_root: Path) -> set[str]:
    """Workspace IDs whose saved .code-workspace / workspace.json file is gone."""
    orphans: set[str] = set()
    if not ws_root.is_dir():
        return orphans
    for entry in ws_root.iterdir():
        if not entry.is_dir() or entry.is_symlink():
            continue
        data = read_json(entry / "workspace.json")
        if not isinstance(data, dict):
            continue
        workspace = data.get("workspace")
        if isinstance(workspace, str) and "Cursor/Workspaces" in workspace:
            path = Path(workspace.removeprefix("file://"))
            if not path.exists():
                orphans.add(entry.name)
    return orphans


def merge_workspace_db(target_dir: Path, source_dir: Path, dry_run: bool) -> int:
    target_db = target_dir / "state.vscdb"
    source_db = source_dir / "state.vscdb"
    if not target_db.is_file() or not source_db.is_file():
        return 0
    merged = 0
    if dry_run:
        return 1
    dst = sqlite3.connect(target_db)
    src = sqlite3.connect(source_db)
    try:
        existing = {
            row[0]
            for row in dst.execute("SELECT key FROM ItemTable").fetchall()
        }
        for key, value in src.execute("SELECT key, value FROM ItemTable"):
            if key in existing:
                continue
            dst.execute("INSERT INTO ItemTable(key, value) VALUES(?, ?)", (key, value))
            merged += 1
        dst.commit()
    finally:
        src.close()
        dst.close()
    return merged


def remap_composers(
    composers: list,
    id_map: dict[str, str],
    canonical_for_folder: dict[str, str],
    folder_uri_alias: dict[str, str],
    composer_folder_index: dict[str, tuple[str, str]] | None = None,
    orphan_ids: set[str] | None = None,
) -> tuple[list, int]:
    composer_folder_index = composer_folder_index or {}
    orphan_ids = orphan_ids or set()
    changed = 0
    for composer in composers:
        if not isinstance(composer, dict):
            continue
        ws = composer.get("workspaceIdentifier")
        if not isinstance(ws, dict):
            continue
        folder_uri = composer_folder_uri(composer)
        if folder_uri and folder_uri in folder_uri_alias:
            folder_uri = folder_uri_alias[folder_uri]
        canonical_id = None
        if folder_uri and folder_uri in canonical_for_folder:
            canonical_id = canonical_for_folder[folder_uri]
        elif ws.get("id") in id_map:
            canonical_id = id_map[ws.get("id")]
        elif ws.get("id") in orphan_ids:
            composer_id = composer.get("composerId")
            if isinstance(composer_id, str) and composer_id in composer_folder_index:
                folder_uri, canonical_id = composer_folder_index[composer_id]

        if canonical_id and ws.get("id") != canonical_id:
            ws["id"] = canonical_id
            changed += 1
            if ws.get("configPath"):
                del ws["configPath"]
                changed += 1

        if folder_uri and folder_uri in canonical_for_folder:
            fs_path = folder_uri.removeprefix("file://")
            uri = ws.get("uri")
            if isinstance(uri, dict):
                uri = dict(uri)
                if uri.get("fsPath") != fs_path or uri.get("external") != folder_uri:
                    uri["fsPath"] = fs_path
                    uri["path"] = fs_path
                    uri["external"] = folder_uri
                    uri.setdefault("$mid", 1)
                    uri.setdefault("scheme", "file")
                    ws["uri"] = uri
                    changed += 1
            elif not uri:
                ws["uri"] = {
                    "$mid": 1,
                    "fsPath": fs_path,
                    "external": folder_uri,
                    "path": fs_path,
                    "scheme": "file",
                }
                changed += 1

        if composer.get("name") or composer.get("type") == "head":
            if composer.get("hasBeenInSidebar") is not True:
                composer["hasBeenInSidebar"] = True
                changed += 1
    return composers, changed


def rebuild_glass_projects(
    composers: list,
    canonical_for_folder: dict[str, str],
    ws_to_folder: dict[str, str],
    home: Path,
) -> tuple[list, dict[str, str]]:
    projects = []
    membership: dict[str, str] = {}

    for composer in composers:
        if not isinstance(composer, dict) or composer.get("type") != "head":
            continue
        composer_id = composer.get("composerId")
        if not isinstance(composer_id, str) or not composer_id:
            continue

        ws = composer.get("workspaceIdentifier")
        if not isinstance(ws, dict):
            continue

        folder_uri = composer_folder_uri(composer)
        ws_id = ws.get("id")
        if not folder_uri and isinstance(ws_id, str):
            folder_uri = ws_to_folder.get(ws_id)
        if folder_uri and folder_uri in canonical_for_folder:
            ws_id = canonical_for_folder[folder_uri]

        uri = ws.get("uri")
        if not isinstance(uri, dict) and folder_uri:
            fs_path = folder_uri.removeprefix("file://")
            uri = {
                "$mid": 1,
                "fsPath": fs_path,
                "external": folder_uri,
                "path": fs_path,
                "scheme": "file",
            }
        elif isinstance(uri, dict) and folder_uri and folder_uri in canonical_for_folder:
            uri = dict(uri)
            uri["external"] = folder_uri
            if "fsPath" not in uri and folder_uri.startswith("file://"):
                uri["fsPath"] = folder_uri.removeprefix("file://")
                uri["path"] = uri["fsPath"]

        name = composer.get("name") or "Untitled chat"
        created = composer.get("createdAt") or composer.get("lastUpdatedAt") or 0
        updated = composer.get("lastUpdatedAt") or created

        project = {
            "id": composer_id,
            "name": name,
            "workspace": {"id": ws_id, "uri": uri},
            "createdAt": created,
            "lastUpdatedAt": updated,
            "isArchived": bool(composer.get("isArchived", False)),
        }
        projects.append(project)
        membership[composer_id] = composer_id

    projects_root = home / ".cursor/projects"
    if projects_root.is_dir():
        for project_dir in projects_root.iterdir():
            if not project_dir.is_dir():
                continue
            transcripts_dir = project_dir / "agent-transcripts"
            if not transcripts_dir.is_dir():
                continue
            for chat_dir in transcripts_dir.iterdir():
                if not chat_dir.is_dir():
                    continue
                parent_id = chat_dir.name
                project_id = membership.get(parent_id, parent_id)
                membership[parent_id] = project_id
                subagents = chat_dir / "subagents"
                if subagents.is_dir():
                    for sub in subagents.glob("*.jsonl"):
                        membership[sub.stem] = project_id

    projects.sort(key=lambda p: p.get("lastUpdatedAt") or 0, reverse=True)
    return projects, membership


def patch_storage_json(
    storage_json: Path,
    id_map: dict[str, str],
    canonical_for_folder: dict[str, str],
    dry_run: bool,
) -> bool:
    if not storage_json.is_file():
        return False
    data = read_json(storage_json)
    if not isinstance(data, dict):
        return False

    canonical_ids = set(canonical_for_folder.values())
    changed = False
    override = data.get("windowSplashWorkspaceOverride")
    if isinstance(override, dict):
        layout = override.get("layoutInfo")
        if isinstance(layout, dict):
            widths = layout.get("auxiliarySideBarWidth")
            if isinstance(widths, list) and len(widths) == 2 and isinstance(widths[1], list):
                new_ids = []
                for ws_id in widths[1]:
                    mapped = id_map.get(ws_id, ws_id)
                    if mapped in canonical_ids and mapped not in new_ids:
                        new_ids.append(mapped)
                    elif mapped != ws_id:
                        changed = True
                for cid in canonical_ids:
                    if cid not in new_ids:
                        new_ids.append(cid)
                        changed = True
                if changed:
                    layout["auxiliarySideBarWidth"] = [widths[0], new_ids]

    if changed and not dry_run:
        write_json(storage_json, data, dry_run=False)
    return changed


def collect_workspace_groups(ws_root: Path) -> dict[str, list[tuple[str, Path]]]:
    groups: dict[str, list[tuple[str, Path]]] = defaultdict(list)
    if not ws_root.is_dir():
        return groups
    for entry in ws_root.iterdir():
        if not entry.is_dir() or entry.is_symlink():
            continue
        workspace_json = entry / "workspace.json"
        if not workspace_json.is_file() and not workspace_json.is_symlink():
            continue
        key = workspace_folder_key(workspace_json)
        if key:
            groups[key].append((entry.name, entry))
    return groups


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--home", default=os.environ.get("HOME", ""), help="Target home directory")
    parser.add_argument(
        "--backup-home",
        default=os.environ.get("OLD_HOME", ""),
        help="Mounted backup home (optional, prefers workspaces present on backup)",
    )
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument(
        "--skip-glass-rebuild",
        action="store_true",
        help="Only dedupe workspaceStorage; do not rebuild Glass agent projects",
    )
    args = parser.parse_args()

    home = Path(args.home).expanduser()
    if not home.is_dir():
        print(f"fix-cursor-workspaces: home not found: {home}", file=sys.stderr)
        return 1

    ws_root = home / ".config/Cursor/User/workspaceStorage"
    global_db = home / ".config/Cursor/User/globalStorage/state.vscdb"
    storage_json = home / ".config/Cursor/User/globalStorage/storage.json"
    backup_home = Path(args.backup_home).expanduser() if args.backup_home else None
    backup_ws_root = (
        backup_home / ".config/Cursor/User/workspaceStorage"
        if backup_home and backup_home.is_dir()
        else None
    )

    if not global_db.is_file():
        print("No Cursor globalStorage database found — nothing to fix.")
        return 0

    groups = collect_workspace_groups(ws_root)
    if not groups:
        print("No Cursor workspace folders found.")
        return 0

    composers = load_composers(global_db)
    groups, folder_uri_alias = merge_groups_by_realpath(groups, composers, backup_ws_root)
    if folder_uri_alias:
        print("Merged symlink-equivalent folder paths:")
        for alias_uri, canonical_uri in sorted(folder_uri_alias.items()):
            print(f"  {alias_uri}")
            print(f"    -> {canonical_uri}")

    ws_to_folder: dict[str, str] = {}
    for folder_uri, entries in groups.items():
        for ws_id, _ in entries:
            ws_to_folder[ws_id] = folder_uri

    id_map: dict[str, str] = {}
    canonical_for_folder: dict[str, str] = {}
    removed_dirs: list[tuple[Path, Path]] = []

    duplicate_count = sum(1 for entries in groups.values() if len(entries) > 1)
    if duplicate_count:
        print(f"Found {duplicate_count} folder path(s) with duplicate workspace IDs:")
    else:
        print("No duplicate workspace folders (will still rebuild Glass projects if needed).")

    for folder_uri, entries in sorted(groups.items()):
        scored = []
        for ws_id, ws_dir in entries:
            backup_dir = backup_ws_root / ws_id if backup_ws_root else None
            scored.append(
                (
                    score_workspace(ws_id, ws_dir, backup_dir, composers),
                    ws_id,
                    ws_dir,
                )
            )
        scored.sort(reverse=True)
        keep_score, keep_id, keep_dir = scored[0]
        canonical_for_folder[folder_uri] = keep_id

        if len(entries) > 1:
            print(f"\n  {folder_uri}")
            print(f"    keep   {keep_id}  (score {keep_score})")
        for score, ws_id, ws_dir in scored[1:]:
            if len(entries) > 1:
                print(f"    remove {ws_id}  (score {score})")
            id_map[ws_id] = keep_id
            removed_dirs.append((ws_dir, keep_dir))

    for alias_uri, canonical_uri in folder_uri_alias.items():
        if canonical_uri in canonical_for_folder:
            canonical_for_folder[alias_uri] = canonical_for_folder[canonical_uri]

    composer_folder_index = build_composer_folder_index(ws_root, canonical_for_folder)
    orphan_ids = orphan_workspace_ids(ws_root)
    if orphan_ids:
        print(f"Found {len(orphan_ids)} orphaned workspace file ID(s) (missing .code-workspace):")
        for oid in sorted(orphan_ids):
            print(f"  {oid}")

    composers, composer_changes = remap_composers(
        composers,
        id_map,
        canonical_for_folder,
        folder_uri_alias,
        composer_folder_index,
        orphan_ids,
    )

    glass_projects: list = []
    glass_membership: dict[str, str] = {}
    if not args.skip_glass_rebuild:
        glass_projects, glass_membership = rebuild_glass_projects(
            composers, canonical_for_folder, ws_to_folder, home
        )

    storage_changed = patch_storage_json(
        storage_json, id_map, canonical_for_folder, args.dry_run
    )

    if args.dry_run:
        print(f"\nDry run summary:")
        print(f"  workspace folders to remove/symlink: {len(removed_dirs)}")
        print(f"  composer header updates: {composer_changes}")
        if not args.skip_glass_rebuild:
            print(f"  glass projects to write: {len(glass_projects)}")
            print(f"  glass membership entries: {len(glass_membership)}")
        if storage_changed:
            print("  would patch storage.json workspace ID list")
        return 0

    merged_rows = 0
    symlink_count = 0
    for drop_dir, keep_dir in removed_dirs:
        merged_rows += merge_workspace_db(keep_dir, drop_dir, dry_run=False)
        drop_id = drop_dir.name
        shutil.rmtree(drop_dir)
        link_path = ws_root / drop_id
        if not link_path.exists():
            link_path.symlink_to(keep_dir.name)
            symlink_count += 1

    if composer_changes:
        save_composers(global_db, composers, dry_run=False)
        print(f"Updated {composer_changes} composer header field(s)")

    if not args.skip_glass_rebuild:
        save_global_value(global_db, "glass.localAgentProjects.v1", glass_projects, False)
        save_global_value(
            global_db, "glass.localAgentProjectMembership.v1", glass_membership, False
        )
        archived = sum(1 for p in glass_projects if p.get("isArchived"))
        print(
            f"Rebuilt Glass agent index: {len(glass_projects)} chats "
            f"({archived} archived), {len(glass_membership)} membership entries"
        )

    write_json(
        home / ".config/Cursor/User/globalStorage/migrate-canonical-workspaces.json",
        canonical_for_folder,
        dry_run=False,
    )

    if storage_changed:
        print("Updated storage.json workspace ID list")
    if merged_rows:
        print(f"Merged {merged_rows} workspace DB row(s) into canonical workspaces")
    if symlink_count:
        print(
            f"Linked {symlink_count} duplicate workspace ID(s) to canonical data "
            "(so reopening folders still finds old chats)"
        )

    print("\nDone. Quit Cursor before running this; reopen folders after it finishes.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
