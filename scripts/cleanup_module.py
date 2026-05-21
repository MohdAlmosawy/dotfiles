#!/usr/bin/env python3
"""
Clean up a scaffolded Odoo module by removing unnecessary files and directories.

This script automates the cleanup process after scaffolding an Odoo module:
- Removes controllers directory
- Removes demo directory
- Removes views/templates.xml and views/views.xml (keeps views directory)
- Cleans models/__init__.py to just encoding comment
- Cleans security/ir.model.access.csv to just header
- Cleans __init__.py to remove controllers import
- Cleans __manifest__.py to remove demo section and empty data array
"""
from __future__ import annotations

import argparse
import ast
import os
import shutil
import sys
from pathlib import Path
from typing import Optional

_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if _SCRIPT_DIR not in sys.path:
    sys.path.insert(0, _SCRIPT_DIR)
from odoo_manifest import find_manifest_dict_node, parse_manifest_dict_node


def read_file(path: str) -> str:
    """Read file content."""
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def write_file(path: str, data: str) -> None:
    """Write file content."""
    with open(path, "w", encoding="utf-8") as f:
        f.write(data)


def node_region_offsets(source: str, node: ast.AST) -> tuple[int, int]:
    """Return (start_index, end_index) offsets in the source string for the AST node."""
    lines = source.splitlines(keepends=True)
    if not (hasattr(node, "lineno") and hasattr(node, "end_lineno")):
        raise RuntimeError("AST node does not contain position information")
    start_line = node.lineno - 1
    end_line = node.end_lineno - 1
    start_index = sum(len(l) for l in lines[:start_line]) + node.col_offset
    end_index = sum(len(l) for l in lines[:end_line]) + node.end_col_offset
    return start_index, end_index


def cleanup_manifest(manifest_path: str, dry_run: bool = False) -> bool:
    """Clean up __manifest__.py: remove demo section and empty data array."""
    src = read_file(manifest_path)
    try:
        tree = ast.parse(src, filename=manifest_path)
    except SyntaxError as exc:
        print(f"Skipping {manifest_path}: parse error: {exc}")
        return False

    dict_node = find_manifest_dict_node(tree)
    if dict_node is None:
        print(f"No top-level manifest dict found in {manifest_path}")
        return False

    try:
        manifest_dict = parse_manifest_dict_node(src, dict_node, manifest_path)
    except Exception as exc:
        print(f"Skipping {manifest_path}: could not parse manifest dict: {exc}")
        return False

    if not isinstance(manifest_dict, dict):
        print(f"Skipping {manifest_path}: manifest is not a dict")
        return False

    # Remove demo key if it exists
    if "demo" in manifest_dict:
        del manifest_dict["demo"]

    # Empty data array if it exists
    if "data" in manifest_dict:
        manifest_dict["data"] = []

    # Format the updated dict back
    start, end = node_region_offsets(src, dict_node)
    old_dict_text = src[start:end]

    # Format dict with proper handling of multi-line strings
    new_dict_lines = ["{"]
    indent = "    "
    
    # Order of keys (matching common Odoo manifest structure)
    key_order = [
        "name", "summary", "description", "author", "maintainer", "website",
        "category", "version", "license", "depends", "data",
        "application", "installable", "auto_install"
    ]
    
    def format_value(key: str, value) -> list[str]:
        """Format a manifest value, returning list of lines."""
        lines = []
        if isinstance(value, str):
            # For summary and description, use triple-quoted strings if multi-line
            if key in ("summary", "description") and ("\n" in value or len(value) > 60):
                # Use triple-quoted string with proper indentation
                inner_indent = indent + "    "
                lines.append(f'{indent}"{key}": """')
                for line in value.strip().split("\n"):
                    lines.append(f"{inner_indent}{line}")
                lines.append(f'{indent}""",')
            else:
                # Single-line string
                escaped = value.replace('"', '\\"').replace("\n", "\\n")
                lines.append(f'{indent}"{key}": "{escaped}",')
        elif isinstance(value, list):
            if not value:
                lines.append(f'{indent}"{key}": [],')
            else:
                lines.append(f'{indent}"{key}": [')
                for item in value:
                    escaped_item = item.replace('"', '\\"')
                    lines.append(f'{indent}    "{escaped_item}",')
                lines.append(f'{indent}],')
        elif isinstance(value, bool):
            lines.append(f'{indent}"{key}": {repr(value)},')
        else:
            lines.append(f'{indent}"{key}": {repr(value)},')
        return lines
    
    # Add keys in preferred order
    used_keys = set()
    for key in key_order:
        if key in manifest_dict:
            used_keys.add(key)
            new_dict_lines.extend(format_value(key, manifest_dict[key]))
    
    # Add any remaining keys
    for key in sorted(k for k in manifest_dict.keys() if k not in used_keys):
        new_dict_lines.extend(format_value(key, manifest_dict[key]))
    
    # Remove trailing blank line before closing brace
    while new_dict_lines and new_dict_lines[-1] == "":
        new_dict_lines.pop()
    
    new_dict_lines.append("}")
    new_dict_text = "\n".join(new_dict_lines)

    # Check if anything changed
    if old_dict_text.strip() == new_dict_text.strip():
        if not dry_run:
            print(f"No changes needed for {manifest_path}")
        return False

    if dry_run:
        print(f"[dry-run] Would update {manifest_path}")
        return True

    # Preserve everything before and after the dict (encoding comment, etc.)
    new_src = src[:start] + new_dict_text + src[end:]
    write_file(manifest_path, new_src)
    print(f"Updated manifest: {manifest_path}")
    return True


def cleanup_init_py(init_path: str, dry_run: bool = False) -> bool:
    """Clean up __init__.py: remove controllers import, keep models import."""
    if not os.path.exists(init_path):
        return False

    src = read_file(init_path)
    lines = src.splitlines()
    
    # Filter out controllers import
    new_lines = []
    changed = False
    for line in lines:
        stripped = line.strip()
        # Skip controllers import line
        if "from . import controllers" in stripped or 'from . import controllers' in stripped:
            changed = True
            continue
        new_lines.append(line)
    
    if not changed:
        if not dry_run:
            print(f"No changes needed for {init_path}")
        return False

    if dry_run:
        print(f"[dry-run] Would update {init_path}")
        return True

    new_content = "\n".join(new_lines)
    if new_content and not new_content.endswith("\n"):
        new_content += "\n"
    write_file(init_path, new_content)
    print(f"Updated __init__.py: {init_path}")
    return True


def cleanup_models_init(models_init_path: str, dry_run: bool = False) -> bool:
    """Clean up models/__init__.py: keep only encoding comment."""
    if not os.path.exists(models_init_path):
        return False

    expected_content = "# -*- coding: utf-8 -*-\n"
    src = read_file(models_init_path)
    
    # Remove import lines, keep only encoding comment
    lines = src.splitlines()
    new_lines = []
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("# -*- coding"):
            new_lines.append(line)
        elif stripped.startswith("#"):
            # Keep other comments if any
            new_lines.append(line)
        elif stripped:
            # Remove non-comment content
            continue
    
    # Ensure we have at least the encoding comment
    if not new_lines:
        new_lines.append("# -*- coding: utf-8 -*-")
    
    new_content = "\n".join(new_lines)
    if new_content and not new_content.endswith("\n"):
        new_content += "\n"
    
    if src.strip() == new_content.strip():
        if not dry_run:
            print(f"No changes needed for {models_init_path}")
        return False

    if dry_run:
        print(f"[dry-run] Would update {models_init_path}")
        return True

    write_file(models_init_path, new_content)
    print(f"Updated models/__init__.py: {models_init_path}")
    return True


def cleanup_security_csv(csv_path: str, dry_run: bool = False) -> bool:
    """Clean up security/ir.model.access.csv: keep only header."""
    if not os.path.exists(csv_path):
        return False

    expected_content = "id,name,model_id:id,group_id:id,perm_read,perm_write,perm_create,perm_unlink\n"
    src = read_file(csv_path)
    
    # Keep only the header line
    lines = src.splitlines()
    header_line = None
    for line in lines:
        if line.strip() and "id,name,model_id:id" in line:
            header_line = line
            break
    
    if header_line is None:
        # Use default header if not found
        header_line = "id,name,model_id:id,group_id:id,perm_read,perm_write,perm_create,perm_unlink"
    
    new_content = header_line
    if not new_content.endswith("\n"):
        new_content += "\n"
    
    # Check if there are data rows to remove
    has_data_rows = False
    for line in lines:
        stripped = line.strip()
        if stripped and "id,name,model_id:id" not in stripped:
            has_data_rows = True
            break
    
    if not has_data_rows and src.strip() == new_content.strip():
        if not dry_run:
            print(f"No changes needed for {csv_path}")
        return False

    if dry_run:
        print(f"[dry-run] Would update {csv_path}")
        return True

    write_file(csv_path, new_content)
    print(f"Updated security/ir.model.access.csv: {csv_path}")
    return True


def cleanup_module(module_path: str, dry_run: bool = False) -> bool:
    """Clean up a scaffolded Odoo module."""
    module_path = os.path.abspath(module_path)
    
    if not os.path.isdir(module_path):
        print(f"Error: {module_path} is not a directory")
        return False

    changes_made = False

    # 1. Remove controllers directory
    controllers_dir = os.path.join(module_path, "controllers")
    if os.path.exists(controllers_dir):
        if dry_run:
            print(f"[dry-run] Would remove directory: {controllers_dir}")
        else:
            shutil.rmtree(controllers_dir)
            print(f"Removed directory: {controllers_dir}")
        changes_made = True

    # 2. Remove demo directory
    demo_dir = os.path.join(module_path, "demo")
    if os.path.exists(demo_dir):
        if dry_run:
            print(f"[dry-run] Would remove directory: {demo_dir}")
        else:
            shutil.rmtree(demo_dir)
            print(f"Removed directory: {demo_dir}")
        changes_made = True

    # 3. Remove views/templates.xml and views/views.xml (keep views directory)
    views_dir = os.path.join(module_path, "views")
    templates_xml = os.path.join(views_dir, "templates.xml")
    views_xml = os.path.join(views_dir, "views.xml")
    
    for view_file in [templates_xml, views_xml]:
        if os.path.exists(view_file):
            if dry_run:
                print(f"[dry-run] Would remove file: {view_file}")
            else:
                os.remove(view_file)
                print(f"Removed file: {view_file}")
            changes_made = True

    # 4. Remove models/models.py if it exists
    models_py = os.path.join(module_path, "models", "models.py")
    if os.path.exists(models_py):
        if dry_run:
            print(f"[dry-run] Would remove file: {models_py}")
        else:
            os.remove(models_py)
            print(f"Removed file: {models_py}")
        changes_made = True

    # 5. Clean models/__init__.py
    models_init = os.path.join(module_path, "models", "__init__.py")
    if cleanup_models_init(models_init, dry_run):
        changes_made = True

    # 6. Clean security/ir.model.access.csv
    security_csv = os.path.join(module_path, "security", "ir.model.access.csv")
    if cleanup_security_csv(security_csv, dry_run):
        changes_made = True

    # 7. Clean __init__.py
    init_py = os.path.join(module_path, "__init__.py")
    if cleanup_init_py(init_py, dry_run):
        changes_made = True

    # 8. Clean __manifest__.py
    manifest_py = os.path.join(module_path, "__manifest__.py")
    if os.path.exists(manifest_py):
        if cleanup_manifest(manifest_py, dry_run):
            changes_made = True

    return changes_made


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Clean up a scaffolded Odoo module by removing unnecessary files and directories"
    )
    parser.add_argument(
        "path",
        nargs="?",
        default=".",
        help="Path to the Odoo module directory to clean up (default: current directory)"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be changed without making any changes"
    )

    args = parser.parse_args()

    module_path = os.path.abspath(args.path)
    
    if not os.path.isdir(module_path):
        print(f"Error: {module_path} is not a directory")
        return

    # Check if it looks like an Odoo module
    manifest_path = os.path.join(module_path, "__manifest__.py")
    if not os.path.exists(manifest_path):
        print(f"Warning: {manifest_path} not found. This might not be an Odoo module.")
        response = input("Continue anyway? [y/N]: ")
        if response.strip().lower() not in ("y", "yes"):
            return

    if args.dry_run:
        print("=== DRY RUN MODE ===")
        print()

    changes_made = cleanup_module(module_path, dry_run=args.dry_run)

    if args.dry_run:
        print()
        print("=== END DRY RUN ===")
        if changes_made:
            print("Run without --dry-run to apply these changes.")
    else:
        if changes_made:
            print("Cleanup completed successfully.")
        else:
            print("No cleanup needed - module is already clean.")


if __name__ == "__main__":
    main()
