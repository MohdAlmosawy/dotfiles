#!/usr/bin/env python3
"""Resolve which Anki/Obsidian paths to use on this machine."""

from __future__ import annotations

import json
import os
import platform
import socket
from pathlib import Path
from typing import Any

SKILL_ROOT = Path(__file__).resolve().parents[1]
DEVICES_FILE = SKILL_ROOT / "devices.json"
LOCAL_OVERRIDE = SKILL_ROOT / "devices.local.json"


def expand(path: str | None) -> Path | None:
    if not path:
        return None
    return Path(path).expanduser()


def load_registry() -> dict[str, Any]:
    data = json.loads(DEVICES_FILE.read_text(encoding="utf-8"))
    if LOCAL_OVERRIDE.exists():
        local = json.loads(LOCAL_OVERRIDE.read_text(encoding="utf-8"))
        # Shallow-merge device entries; local wins per device id
        devices = data.setdefault("devices", {})
        for did, cfg in (local.get("devices") or {}).items():
            if did in devices and isinstance(devices[did], dict) and isinstance(cfg, dict):
                merged = {**devices[did], **cfg}
                if "anki" in devices[did] or "anki" in cfg:
                    merged["anki"] = {**(devices[did].get("anki") or {}), **(cfg.get("anki") or {})}
                if "obsidian" in devices[did] or "obsidian" in cfg:
                    merged["obsidian"] = {
                        **(devices[did].get("obsidian") or {}),
                        **(cfg.get("obsidian") or {}),
                    }
                if "match" in devices[did] or "match" in cfg:
                    merged["match"] = {
                        **(devices[did].get("match") or {}),
                        **(cfg.get("match") or {}),
                    }
                devices[did] = merged
            else:
                devices[did] = cfg
    return data


def list_devices() -> list[str]:
    reg = load_registry()
    return sorted(reg.get("devices", {}))


def _hostname() -> str:
    return socket.gethostname().split(".")[0]


def match_device_id(reg: dict[str, Any] | None = None) -> str | None:
    """Pick device id: env ANKI_MSC_DEVICE → hostname match → None."""
    env = os.environ.get("ANKI_MSC_DEVICE", "").strip()
    if env:
        return env

    reg = reg or load_registry()
    host = _hostname().casefold()
    for did, cfg in (reg.get("devices") or {}).items():
        names = [h.casefold() for h in (cfg.get("match") or {}).get("hostnames") or []]
        if host in names:
            return did
    return None


def resolve(device_id: str | None = None) -> dict[str, Any]:
    """
    Return resolved paths for a device.

    Priority for collection DB path:
      1. ANKI_MSC_DB env
      2. device registry collection_db
    """
    reg = load_registry()
    devices = reg.get("devices") or {}
    did = device_id or match_device_id(reg)

    env_db = os.environ.get("ANKI_MSC_DB", "").strip()
    env_db_path = Path(env_db).expanduser() if env_db else None

    if not did:
        return {
            "ok": False,
            "error": "unresolved_device",
            "hostname": _hostname(),
            "platform": platform.system().lower(),
            "known_devices": list(devices),
            "hint": "Set ANKI_MSC_DEVICE, or add this hostname under devices.json match.hostnames, or pass --db.",
            "collection_db": env_db_path,
        }

    if did not in devices:
        return {
            "ok": False,
            "error": "unknown_device",
            "device_id": did,
            "known_devices": list(devices),
            "collection_db": env_db_path,
        }

    cfg = devices[did]
    anki = cfg.get("anki") or {}
    obsidian = cfg.get("obsidian") or {}
    collection = env_db_path or expand(anki.get("collection_db"))
    profile = expand(anki.get("profile_dir"))
    vault = expand(obsidian.get("vault"))
    status = cfg.get("status", "unknown")

    problems: list[str] = []
    if status == "pending":
        problems.append("device status is pending — fill paths in devices.json")
    if collection is None:
        problems.append("collection_db not configured")
    elif not collection.exists():
        problems.append(f"collection_db missing on disk: {collection}")

    return {
        "ok": not problems,
        "device_id": did,
        "label": cfg.get("label", did),
        "status": status,
        "hostname": _hostname(),
        "platform": platform.system().lower(),
        "install": anki.get("install"),
        "profile_dir": profile,
        "collection_db": collection,
        "obsidian_vault": vault,
        "problems": problems,
        "todo": cfg.get("todo"),
    }


def require_collection_db(device_id: str | None = None) -> Path:
    info = resolve(device_id)
    db = info.get("collection_db")
    if not info.get("ok") or not isinstance(db, Path):
        parts = [
            f"Cannot resolve Anki collection (device={info.get('device_id')!r}, host={info.get('hostname')!r}).",
            *(info.get("problems") or []),
            info.get("hint") or info.get("todo") or "",
            f"Known devices: {', '.join(info.get('known_devices') or list_devices())}",
            f"Edit: {DEVICES_FILE}",
            f"Optional override: {LOCAL_OVERRIDE}",
        ]
        raise SystemExit("\n".join(p for p in parts if p))
    return db


def main() -> None:
    import argparse

    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--device", default=None, help="Force device id from devices.json")
    ap.add_argument("--json", action="store_true", help="Print JSON")
    args = ap.parse_args()
    info = resolve(args.device)
    if args.json:
        out = {
            **info,
            "profile_dir": str(info["profile_dir"]) if info.get("profile_dir") else None,
            "collection_db": str(info["collection_db"]) if info.get("collection_db") else None,
            "obsidian_vault": str(info["obsidian_vault"]) if info.get("obsidian_vault") else None,
        }
        print(json.dumps(out, indent=2))
        return
    print(f"device:     {info.get('device_id')} ({info.get('label')})")
    print(f"status:     {info.get('status')}")
    print(f"hostname:   {info.get('hostname')}")
    print(f"ok:         {info.get('ok')}")
    print(f"profile:    {info.get('profile_dir')}")
    print(f"collection: {info.get('collection_db')}")
    print(f"obsidian:   {info.get('obsidian_vault')}")
    if info.get("problems"):
        print("problems:")
        for p in info["problems"]:
            print(f"  - {p}")
    if info.get("todo"):
        print(f"todo:       {info['todo']}")
    if info.get("hint"):
        print(f"hint:       {info['hint']}")


if __name__ == "__main__":
    main()
