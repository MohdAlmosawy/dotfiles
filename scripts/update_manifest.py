#!/usr/bin/env python3
"""
Update or add default values into Odoo __manifest__.py files.

This script searches for `__manifest__.py` files (or a specific file) and
updates the manifest dictionary with provided defaults. It parses the file
with the AST module so it does not execute arbitrary code.

Features:
- Safe parsing of top-level dict expression or assignment to a name
- Update/add keys: author, license, version, application, installable, auto_install
- Recursive search in directories
- Dry-run and backup support
"""
from __future__ import annotations

import argparse
import ast
import os
import textwrap
import pprint
from typing import Dict, Optional, Tuple


DEFAULT_AUTHOR_NAME = "Sayed Mohammed Aqeel Ebrahim"
DEFAULT_PARTNER = "Al-Salam-Gas"
DEFAULT_AUTHOR = f"{DEFAULT_PARTNER}, {DEFAULT_AUTHOR_NAME}"
DEFAULT_LICENSE = "LGPL-3"
DEFAULT_ODOO_MAJOR = 16
DEFAULT_WEBSITE = "https://sayedmohd.com/"


def build_version_from_major(major: int) -> str:
    # simple convention: <major>.0.1.0.0
    return f"{major}.0.1.0.0"


def find_manifest_nodes(tree: ast.Module) -> Optional[ast.AST]:
    """Return the AST node of the first top-level dict expression or assignment's value that is a Dict.

    Supports both a bare dict (Expression -> Dict) and assignment like: manifest = { ... }
    """
    for node in tree.body:
        # bare dict as an Expr (common in __manifest__.py)
        if isinstance(node, ast.Expr) and isinstance(node.value, ast.Dict):
            return node.value
        # assignment to a name: NAME = { ... }
        if isinstance(node, ast.Assign) and isinstance(node.value, ast.Dict):
            return node.value
    return None


def read_file(path: str) -> str:
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def write_file(path: str, data: str) -> None:
    with open(path, "w", encoding="utf-8") as f:
        f.write(data)


def node_region_offsets(source: str, node: ast.AST) -> Tuple[int, int]:
    """Return (start_index, end_index) offsets in the source string for the AST node.

    Requires that the AST node has lineno, col_offset, end_lineno, end_col_offset (Python 3.8+).
    """
    lines = source.splitlines(keepends=True)
    if not (hasattr(node, "lineno") and hasattr(node, "end_lineno")):
        raise RuntimeError("AST node does not contain position information")
    start_line = node.lineno - 1
    end_line = node.end_lineno - 1
    # sum lengths of lines before start_line
    start_index = sum(len(l) for l in lines[:start_line]) + node.col_offset
    end_index = sum(len(l) for l in lines[:end_line]) + node.end_col_offset
    return start_index, end_index


def _quote_str(value: str, indent: int) -> str:
    """Return a Python string literal. Use triple-quoted string for multi-line values.

    indent is number of spaces for the dict indentation (e.g. 4).
    """
    if value is None:
        return "''"
    # Normalize newlines
    s = value.rstrip()
    inner_indent = ' ' * (indent + 4)
    if '\n' in s or len(s) > 80:
        # Use triple-quoted string with a leading newline and indented content
        content = s.strip('\n')
        indented = textwrap.indent(content, inner_indent)
        return '"""\n' + indented + '\n' + (' ' * indent) + '"""'
    # single-line -> use double quotes and escape
    esc = s.replace('"', '\\"')
    return f'"{esc}"'


def _render_list(items: list, indent: int) -> str:
    indent_str = ' ' * indent
    inner_indent = ' ' * (indent + 4)
    if not items:
        return '[]'
    lines = ['[']
    for it in items:
        if isinstance(it, str):
            lines.append(f"{inner_indent}{_quote_str(it, indent + 4)},")
        else:
            lines.append(f"{inner_indent}{repr(it)},")
    lines.append(f"{indent_str}]")
    return '\n'.join(lines)


def format_manifest_dict(d: Dict) -> str:
    """Render the manifest dict as a nicely formatted Python dict string.

    This tries to follow common Odoo manifest formatting: ordered keys, triple-quoted
    summary/description when they contain newlines, lists each element on its own line.
    """
    # Preferred ordering of keys for readability
    preferred = [
        'name', 'summary', 'description', 'author', 'maintainer', 'website', 'category', 'version', 'license', 'currency', 'price',
        'depends', 'data', 'application', 'installable', 'auto_install'
    ]
    indent = 4
    indent_str = ' ' * indent
    lines = ['{']

    # Helper to append a key/value pair
    def append_kv(key: str, val_repr: str):
        lines.append(f"{indent_str}'{key}': {val_repr},")

    used = set()
    for key in preferred:
        if key in d:
            v = d[key]
            used.add(key)
            if key in ('summary', 'description') and isinstance(v, str):
                # Render as triple-quoted block for readability
                q = _quote_str(v, indent)
                append_kv(key, q)
            elif isinstance(v, str):
                append_kv(key, _quote_str(v, indent))
            elif isinstance(v, list):
                append_kv(key, _render_list(v, indent))
            else:
                append_kv(key, repr(v))

    # Any other keys (keep deterministic order)
    for key in sorted(k for k in d.keys() if k not in used):
        v = d[key]
        if isinstance(v, str):
            append_kv(key, _quote_str(v, indent))
        elif isinstance(v, list):
            append_kv(key, _render_list(v, indent))
        else:
            append_kv(key, repr(v))

    lines.append('}')
    return '\n'.join(lines) + '\n'


def process_file(path: str, defaults: Dict[str, object], dry_run: bool = False, backup: bool = True, debug: bool = False) -> bool:
    """Process a single __manifest__.py file. Returns True if file was changed.
    """
    src = read_file(path)
    try:
        tree = ast.parse(src, filename=path)
    except SyntaxError as exc:
        print(f"Skipping {path}: parse error: {exc}")
        return False

    dict_node = find_manifest_nodes(tree)
    if dict_node is None:
        print(f"No top-level manifest dict found in {path}")
        return False

    # Safely evaluate the dict node
    try:
        current = ast.literal_eval(dict_node)
    except Exception as exc:
        print(f"Skipping {path}: could not literal_eval manifest dict: {exc}")
        return False

    if debug:
        print("--- parsed manifest dict (ast.literal_eval) ---")
        pprint.pprint(current)
        print("--------------------------------------------")

    if not isinstance(current, dict):
        print(f"Skipping {path}: manifest is not a dict")
        return False

    updated = dict(current)  # copy
    for k, v in defaults.items():
        updated[k] = v

    # Render formatted dict
    new_dict_text = format_manifest_dict(updated)

    if debug:
        print("--- updated manifest dict to be written ---")
        pprint.pprint(updated)
        print("------------------------------------------")

    # Replace the region corresponding to the dict_node with the new dict text
    try:
        start, end = node_region_offsets(src, dict_node)
    except Exception as exc:
        print(f"Failed to compute node offsets for {path}: {exc}")
        return False

    old_segment = src[start:end]
    if old_segment.strip() == new_dict_text.strip():
        print(f"No changes needed for {path}")
        return False

    new_src = src[:start] + new_dict_text + src[end:]

    if dry_run:
        print(f"[dry-run] Would update {path}")
        return True

    if backup:
        bak = path + ".bak"
        with open(bak, "w", encoding="utf-8") as f:
            f.write(src)
        print(f"Backup written to {bak}")

    write_file(path, new_src)
    print(f"Updated manifest: {path}")
    return True


def find_manifest_files(path: str) -> list[str]:
    # If user passed a file path directly, accept it.
    if os.path.isfile(path) and os.path.basename(path) == "__manifest__.py":
        return [path]
    # If it's a directory, search recursively for __manifest__.py
    res = []
    for root, dirs, files in os.walk(path):
        if "__manifest__.py" in files:
            res.append(os.path.join(root, "__manifest__.py"))
    return res


def main() -> None:
    parser = argparse.ArgumentParser(description="Small CLI to update Odoo __manifest__.py files with project defaults")
    parser.add_argument("path", nargs="?", default=".", help="File or directory to update (default: current directory)")
    # --application expects an explicit value: yes or no. If omitted, we will
    # still prompt interactively.
    parser.add_argument("--application", choices=["yes", "no"], help="Set the manifest as an application: 'yes' or 'no' (overrides interactive prompt)")
    parser.add_argument("--odoo-major", type=int, help="Odoo major version (e.g. 16). If provided, version becomes '<major>.0.1.0.0'")
    parser.add_argument("--version", help="Full version string to set (overrides --odoo-major)")
    parser.add_argument("--website", help="Website URL to set in manifest (overrides default)")
    parser.add_argument("--partner", help="Optional partner/entity name to prefix the author (e.g. 'alsalam' or 'tecpill' or a custom name). Use 'none' to keep only your name.")
    parser.add_argument("--paid", choices=["yes", "no"], help="Is this a paid module? 'yes' or 'no' (overrides interactive prompt)")
    parser.add_argument("--price", type=float, help="Price amount when module is paid (defaults to 25)")
    parser.add_argument("--currency", help="Currency code for paid modules (defaults to USD)")
    parser.add_argument("--debug", action="store_true", help="Print parsed and updated manifest dicts for debugging")

    args = parser.parse_args()

    # Determine application flag: if not provided, ask the user once interactively.
    # args.application (from argparse) may be 'yes' or 'no' or None.
    if args.application is None:
        resp = input("Is this module an application? [y/N]: ")
        app_bool = resp.strip().lower() in ("y", "yes", "1")
    else:
        app_bool = True if args.application == "yes" else False

    # Determine version: prefer --version (full), then --odoo-major, then interactive prompt
    version_value: str
    if args.version:
        version_value = args.version
    else:
        major = args.odoo_major
        if major is None:
            resp = input(f"Enter Odoo major version (e.g. 16) or press Enter for default {DEFAULT_ODOO_MAJOR}: ")
            resp = resp.strip()
            if resp == "":
                major = DEFAULT_ODOO_MAJOR
            else:
                # allow entering full version string too
                if "." in resp:
                    version_value = resp
                    major = None
                else:
                    try:
                        major = int(resp)
                    except ValueError:
                        print("Invalid input; using default major version")
                        major = DEFAULT_ODOO_MAJOR

        if major is not None:
            version_value = build_version_from_major(major)

        # Paid module handling: ask or use CLI flag
        if args.paid is None:
            paid_resp = input("Is this a paid module? [y/N]: ")
            paid_bool = paid_resp.strip().lower() in ("y", "yes", "1")
        else:
            paid_bool = True if args.paid == "yes" else False

        price_value = None
        currency_value = None
        if paid_bool:
            # determine currency
            currency_value = args.currency if args.currency else "USD"
            # determine price
            if args.price is not None:
                price_value = args.price
            else:
                p = input("Enter price amount (default 25): ")
                p = p.strip()
                if p == "":
                    price_value = 25
                else:
                    try:
                        price_value = float(p)
                        # if it's an integer value, keep it as int
                        if price_value.is_integer():
                            price_value = int(price_value)
                    except ValueError:
                        print("Invalid price; using default 25")
                        price_value = 25

    # Determine partner/author composition: if not provided on CLI, ask interactively.
    if args.partner is None:
        p_resp = input("Partner/co-author (press Enter for 'alsalam', type 'none' for only you, or enter a custom name): ")
        p_resp = p_resp.strip()
        if p_resp == "":
            partner_input = "alsalam"
        else:
            partner_input = p_resp
    else:
        partner_input = args.partner
    partner_map = {
        "alsalam": "Al-Salam-Gas",
        "tecpill": "Technology Pill Business Solution",
    }

    if partner_input:
        low = partner_input.strip().lower()
        if low == "none":
            author_value = DEFAULT_AUTHOR_NAME
        elif low in partner_map:
            author_value = f"{partner_map[low]}, {DEFAULT_AUTHOR_NAME}"
        else:
            # Use the raw partner_input as provided
            author_value = f"{partner_input.strip()}, {DEFAULT_AUTHOR_NAME}"
    else:
        # default preserves previous behavior (include DEFAULT_PARTNER)
        author_value = DEFAULT_AUTHOR

    website_value = args.website if args.website else DEFAULT_WEBSITE
    # Build defaults and add paid fields if applicable
    if paid_bool:
        license_value = "OPL-1"
    else:
        license_value = DEFAULT_LICENSE

    defaults = {
        "author": author_value,
        "maintainer": DEFAULT_AUTHOR_NAME,
        "license": license_value,
        "version": version_value,
        "application": app_bool,
        "installable": True,
        "auto_install": False,
        "website": website_value,
    }

    if paid_bool:
        defaults["currency"] = currency_value
        defaults["price"] = price_value

    files = find_manifest_files(args.path)
    if not files:
        print("No __manifest__.py files found in the given path")
        return

    any_changed = False
    for path in files:
        changed = process_file(path, defaults, dry_run=False, backup=False, debug=args.debug)
        any_changed = any_changed or changed

    if any_changed:
        print("Done.")
    else:
        print("No files changed.")


if __name__ == "__main__":
    main()
