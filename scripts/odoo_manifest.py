#!/usr/bin/env python3
"""Shared Odoo __manifest__.py parsing utilities.

Handles common invalid literals (JSON-style true/false/null) before ast.literal_eval,
matching what Odoo expects (Python True/False/None).
"""
from __future__ import annotations

import ast
import io
import tokenize
from typing import Any, Optional


def normalize_manifest_source(source: str) -> str:
    """Rewrite JSON-style true/false/null to Python literals outside strings/comments."""
    out: list[tokenize.TokenInfo] = []
    readline = io.StringIO(source).readline
    for tok in tokenize.generate_tokens(readline):
        if tok.type == tokenize.NAME:
            repl = {"true": "True", "false": "False", "null": "None"}.get(tok.string)
            if repl is not None:
                out.append(tok._replace(string=repl))
                continue
        out.append(tok)
    return tokenize.untokenize(out)


def find_manifest_dict_node(tree: ast.Module) -> Optional[ast.AST]:
    """Return the AST node of the first top-level dict (bare expr or assignment)."""
    for node in tree.body:
        if isinstance(node, ast.Expr) and isinstance(node.value, ast.Dict):
            return node.value
        if isinstance(node, ast.Assign) and isinstance(node.value, ast.Dict):
            return node.value
    return None


def parse_manifest_dict_node(source: str, dict_node: ast.AST, filename: str = "<manifest>") -> dict[str, Any]:
    """Parse a manifest dict AST node, normalizing JSON-style literals first."""
    segment = ast.get_source_segment(source, dict_node)
    if segment is None:
        raise ValueError(f"Could not extract manifest dict from {filename}")
    normalized = normalize_manifest_source(segment)
    result = ast.literal_eval(normalized)
    if not isinstance(result, dict):
        raise TypeError(f"Manifest in {filename} is not a dict")
    return result


def parse_manifest_source(source: str, filename: str = "<manifest>") -> dict[str, Any]:
    """Parse manifest file content (encoding line + bare dict or assignment)."""
    tree = ast.parse(source, filename=filename)
    dict_node = find_manifest_dict_node(tree)
    if dict_node is None:
        raise ValueError(f"No top-level manifest dict found in {filename}")
    return parse_manifest_dict_node(source, dict_node, filename)


def parse_manifest_file(path: str) -> dict[str, Any]:
    with open(path, encoding="utf-8") as f:
        source = f.read()
    return parse_manifest_source(source, path)


def get_manifest_depends(path: str) -> list[str]:
    depends = parse_manifest_file(path).get("depends", [])
    if not depends:
        return []
    if not isinstance(depends, list):
        raise TypeError(f"'depends' in {path} is not a list")
    return [str(d) for d in depends]
