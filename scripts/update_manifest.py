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
import io
import tokenize
from typing import List
import re
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


def format_manifest_blocks(d: Dict) -> List[tuple[str, List[str]]]:
    """Return ordered list of (key, block_lines) for the manifest dict.

    Each block_lines is the formatted lines (no trailing blank line). Caller
    can insert comments or blank lines as desired when assembling the final
    dict text.
    """
    preferred = [
        'name', 'summary', 'description', 'author', 'maintainer', 'website', 'category', 'version', 'license', 'currency', 'price',
        'depends', 'data', 'application', 'installable', 'auto_install'
    ]
    indent = 4
    indent_str = ' ' * indent
    blocks: List[tuple[str, List[str]]] = []
    used = set()

    def make_block(key: str, v) -> List[str]:
        lines: List[str] = []
        if key in ('summary', 'description') and isinstance(v, str):
            q = _quote_str(v, indent)
            lines.append(f"{indent_str}'{key}': {q},")
        elif isinstance(v, str):
            lines.append(f"{indent_str}'{key}': {_quote_str(v, indent)},")
        elif isinstance(v, list):
            lst = _render_list(v, indent)
            lst_lines = lst.splitlines()
            # first line should be attached to the key
            if lst_lines:
                first = lst_lines[0]
                lines.append(f"{indent_str}'{key}': {first}")
                for ln in lst_lines[1:]:
                    lines.append(indent_str + ln)
                # ensure closing bracket line ends with a comma
                if not lines[-1].rstrip().endswith(','):
                    lines[-1] = lines[-1] + ','
        else:
            lines.append(f"{indent_str}'{key}': {repr(v)},")
        return lines

    for key in preferred:
        if key in d:
            used.add(key)
            blocks.append((key, make_block(key, d[key])))

    for key in sorted(k for k in d.keys() if k not in used):
        blocks.append((key, make_block(key, d[key])))

    return blocks


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
    # If nothing changes (ignoring comments and whitespace), skip
    if old_segment.strip() == new_dict_text.strip():
        print(f"No changes needed for {path}")
        return False

    # We'll use token/line analysis to preserve comments and attach them to keys
    old_lines = old_segment.splitlines()
    # Find key start lines using a regex (keys like 'name':)
    key_re = re.compile(r"^\s*'(?P<key>[^']+)'\s*:")
    key_positions: list[tuple[str, int]] = []  # (key, line_index)
    for idx, ln in enumerate(old_lines):
        m = key_re.match(ln)
        if m:
            key_positions.append((m.group('key'), idx))

    # Build regions per key
    regions: dict[str, tuple[int, int]] = {}
    for i, (k, idx) in enumerate(key_positions):
        start_idx = idx
        end_idx = key_positions[i + 1][1] if i + 1 < len(key_positions) else len(old_lines)
        regions[k] = (start_idx, end_idx)

    # Helper: collect preceding comments for a key (lines immediately above key)
    def collect_preceding_comments(start_idx: int) -> list[str]:
        out: list[str] = []
        i = start_idx - 1
        while i >= 0:
            ln = old_lines[i]
            if ln.strip() == '':
                # stop at blank line (preserve separation)
                break
            if ln.lstrip().startswith('#'):
                out.insert(0, ln)
                i -= 1
                continue
            break
        return out

    # For list-valued keys, capture sequence of old items/comments inside the list
    def parse_old_list_region(start: int, end: int) -> list[tuple[str, str]]:
        # returns sequence of ('item', text) or ('comment', text)
        seq: list[tuple[str, str]] = []
        in_list = False
        for i in range(start, end):
            ln = old_lines[i]
            s = ln.strip()
            if not in_list:
                if s.startswith('['):
                    in_list = True
                    # if bracket and items on same line, continue
                    continue
                else:
                    continue
            else:
                # inside list until we see closing bracket
                if s.startswith(']') or s.endswith('],'):
                    break
                if s.lstrip().startswith('#'):
                    seq.append(('comment', ln.rstrip()))
                else:
                    if s == ',':
                        continue
                    # consider non-empty non-comment as item
                    if s:
                        seq.append(('item', ln.strip().rstrip(',')))
        return seq

    def _looks_like_list_item(line: str) -> bool:
        s = line.strip()
        return bool(s) and (s[0] == '"' or s[0] == "'")

    def _list_line_indent(line: str) -> str:
        # return leading whitespace of the line
        return line[:len(line) - len(line.lstrip(' '))]

    # Build formatted blocks
    blocks = format_manifest_blocks(updated)

    # Collect preserved comments
    comments_before: dict[str, list[str]] = {}
    inline_comments: dict[str, str] = {}
    inside_list_comments: dict[str, list[tuple[str, str]]] = {}
    for key, (kstart, kend) in regions.items():
        # preceding comments
        comments_before[key] = collect_preceding_comments(kstart)
        # inline comment on key line
        ln = old_lines[kstart]
        if '#' in ln:
            parts = ln.split('#', 1)
            inline_comments[key] = '#' + parts[1].rstrip()
        # if key has a list, parse inside comments
        region_seq = parse_old_list_region(kstart, kend)
        if region_seq:
            inside_list_comments[key] = region_seq

    # Assemble new segment, attaching comments
    assembled: list[str] = []
    assembled.append('{')
    # groups that should not be separated by blank lines when adjacent
    group_no_blank = [
        ("author", "maintainer", "website"),
        ("category", "version", "license", "currency", "price"),
        ("application", "installable", "auto_install"),
    ]

    def _same_group(a: str, b: str) -> bool:
        for g in group_no_blank:
            if a in g and b in g:
                return True
        return False
    for key, block_lines in blocks:
        # attach preceding comments (if any)
        pre = comments_before.get(key, [])
        if pre:
            assembled.extend(pre)

        # handle block lines
        if block_lines:
            # if this is a list block and we have inside_list_comments, merge
            if key in inside_list_comments and any('[' in ln for ln in block_lines):
                # reconstruct list with preserved comments
                seq = inside_list_comments[key]
                # find indices of item lines in block_lines
                new_block: list[str] = []
                item_idx = 0
                # find where the '[' occurs
                for ln in block_lines:
                    if '[' in ln:
                        new_block.append(ln)
                        continue
                    if ']' in ln:
                        # before closing bracket, append any remaining items
                        # but we assume items already in place; just append ln
                        new_block.append(ln)
                        continue
                    # assume these are item lines (or commas)
                    new_block.append(ln)

                # now interleave comments: we will insert comment lines before/among items
                # Build simplified list of item lines indices
                item_lines = [i for i, ln in enumerate(new_block) if _looks_like_list_item(ln)]
                merged: list[str] = []
                item_cursor = 0
                for typ, content in seq:
                    if typ == 'comment':
                        # insert comment line with proper indentation
                        # use indentation from the first item or default
                        if item_lines:
                            indent = _list_line_indent(new_block[item_lines[0]])
                        else:
                            indent = ' ' * (4 + 4)
                        merged.append(indent + content.lstrip())
                    else:
                        # output next actual item from new_block
                        if item_cursor < len(item_lines):
                            merged.append(new_block[item_lines[item_cursor]].rstrip())
                            item_cursor += 1
                # append any remaining items not consumed
                while item_cursor < len(item_lines):
                    merged.append(new_block[item_lines[item_cursor]].rstrip())
                    item_cursor += 1

                # build final block: header lines (before first item), merged items, closing lines
                header = []
                footer = []
                seen_items = False
                for ln in new_block:
                    if _looks_like_list_item(ln):
                        seen_items = True
                        break
                    header.append(ln)
                # find closing bracket
                closing_idx = None
                for i, ln in enumerate(new_block[::-1]):
                    if ']' in ln:
                        closing_idx = len(new_block) - 1 - i
                        break
                if closing_idx is not None:
                    footer = new_block[closing_idx:]
                assembled.extend(header)
                for mln in merged:
                    assembled.append(mln)
                assembled.extend(footer)
            else:
                # normal block, attach inline comment if present
                first = block_lines[0]
                if key in inline_comments:
                    first = first.rstrip() + '  ' + inline_comments[key]
                assembled.append(first)
                assembled.extend(block_lines[1:])

        # decide whether to add a blank line between this key and the next
        add_blank = True
        if i + 1 < len(blocks):
            next_key = blocks[i + 1][0]
            if _same_group(key, next_key):
                add_blank = False
        if add_blank:
            assembled.append('')

    if assembled and assembled[-1] == '':
        assembled.pop()
    assembled.append('}')

    # Post-process: remove empty-only lines between keys that belong to the same group
    key_re = re.compile(r"^\s*'(?P<key>[^']+)'\s*:")
    i = 0
    while i < len(assembled):
        m = key_re.match(assembled[i])
        if m:
            cur_key = m.group('key')
            # scan forward to find next key line
            j = i + 1
            while j < len(assembled):
                if assembled[j].strip() == '':
                    j += 1
                    continue
                if assembled[j].lstrip().startswith('#'):
                    j += 1
                    continue
                # found a non-empty non-comment line
                mk = key_re.match(assembled[j])
                if mk:
                    next_key = mk.group('key')
                    # if in same group, remove empty-only lines between i and j
                    if _same_group(cur_key, next_key):
                        k = i + 1
                        while k < j:
                            if assembled[k].strip() == '':
                                assembled.pop(k)
                                j -= 1
                            else:
                                k += 1
                        # we've removed empty-only lines between the grouped keys;
                        # break to advance the outer cursor
                        break
                break
        i += 1

    new_segment = '\n'.join(assembled) + '\n'
    new_src = src[:start] + new_segment + src[end:]

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
