#!/usr/bin/env python3
"""Resolve the MSc host and report whether Anki, Zotero, the vault, and the BOOX are reachable."""

from __future__ import annotations

import json
import os
import platform
import socket
import urllib.error
import urllib.request
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
        devices = data.setdefault("devices", {})
        for did, cfg in (local.get("devices") or {}).items():
            if did in devices and isinstance(devices[did], dict) and isinstance(cfg, dict):
                merged = {**devices[did], **cfg}
                for key in ("anki", "zotero", "obsidian", "match"):
                    if key in devices[did] or key in cfg:
                        merged[key] = {
                            **(devices[did].get(key) or {}),
                            **(cfg.get(key) or {}),
                        }
                devices[did] = merged
            else:
                devices[did] = cfg
    return data


def _hostname() -> str:
    return socket.gethostname().split(".")[0]


def _env_device() -> str:
    return (os.environ.get("MSC_DEVICE") or os.environ.get("ANKI_MSC_DEVICE") or "").strip()


def _env_db() -> Path | None:
    raw = (os.environ.get("MSC_ANKI_DB") or os.environ.get("ANKI_MSC_DB") or "").strip()
    return Path(raw).expanduser() if raw else None


def match_device_id(reg: dict[str, Any] | None = None) -> str | None:
    env = _env_device()
    if env:
        return env

    reg = reg or load_registry()
    host = _hostname().casefold()
    for did, cfg in (reg.get("devices") or {}).items():
        if cfg.get("kind") == "capture":
            continue
        names = [h.casefold() for h in (cfg.get("match") or {}).get("hostnames") or []]
        if host in names:
            return did
    return None


def _proc_cmds() -> list[str]:
    cmds: list[str] = []
    proc = Path("/proc")
    if not proc.is_dir():
        return cmds
    for entry in proc.iterdir():
        if not entry.name.isdigit():
            continue
        try:
            raw = (entry / "cmdline").read_bytes()
        except OSError:
            continue
        if not raw:
            continue
        cmds.append(raw.replace(b"\x00", b" ").decode(errors="ignore"))
    return cmds


def anki_running() -> bool:
    for cmd in _proc_cmds():
        lowered = cmd.casefold()
        if "inspect_cards.py" in lowered or "device.py" in lowered:
            continue
        if "anki-bin" in lowered or "anki-desktop" in lowered or "/bin/anki" in lowered:
            return True
    return False


def zotero_api(api_base: str) -> dict[str, Any]:
    ping = api_base.rstrip("/") + "/connector/ping"
    try:
        with urllib.request.urlopen(ping, timeout=2) as resp:
            body = resp.read(200).decode(errors="ignore")
            code = getattr(resp, "status", 200)
    except urllib.error.HTTPError as exc:
        code = exc.code
        body = exc.read(200).decode(errors="ignore")
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        return {"reachable": False, "detail": f"api down: {exc.__class__.__name__}"}

    if code == 200 and "Zotero is running" in body:
        return {"reachable": True, "detail": "local API up", "api": api_base}
    if code == 403:
        return {"reachable": False, "detail": "Zotero is running; local API is disabled", "api": api_base}
    return {"reachable": False, "detail": f"HTTP {code}", "api": api_base}


def capture_devices(reg: dict[str, Any]) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for did, cfg in (reg.get("devices") or {}).items():
        if cfg.get("kind") != "capture":
            continue
        status = cfg.get("status", "unknown")
        out.append(
            {
                "device_id": did,
                "label": cfg.get("label", did),
                "kind": "capture",
                "status": status,
                "reachable": status == "connected",
                "detail": cfg.get("notes") or status,
            }
        )
    return out


def resolve(device_id: str | None = None) -> dict[str, Any]:
    reg = load_registry()
    devices = reg.get("devices") or {}
    did = device_id or match_device_id(reg)
    env_db_path = _env_db()

    if not did:
        return {
            "ok": False,
            "error": "unresolved_device",
            "hostname": _hostname(),
            "platform": platform.system().lower(),
            "known_devices": list(devices),
            "hint": "Set MSC_DEVICE, or add this hostname under devices.json match.hostnames.",
            "captures": capture_devices(reg),
        }

    if did not in devices:
        return {
            "ok": False,
            "error": "unknown_device",
            "device_id": did,
            "known_devices": list(devices),
            "captures": capture_devices(reg),
        }

    cfg = devices[did]
    if cfg.get("kind") == "capture":
        return {
            "ok": False,
            "error": "capture_device",
            "device_id": did,
            "hint": "A capture device is not a host. Resolve the laptop or AlSalam PC.",
            "captures": capture_devices(reg),
        }

    anki = cfg.get("anki") or {}
    zotero = cfg.get("zotero") or {}
    obsidian = cfg.get("obsidian") or {}
    collection = env_db_path or expand(anki.get("collection_db"))
    profile = expand(anki.get("profile_dir"))
    vault = expand(obsidian.get("vault"))
    data_dir = expand(zotero.get("data_dir"))
    api = zotero.get("api") or "http://127.0.0.1:23119"
    status = cfg.get("status", "unknown")

    problems: list[str] = []
    if status in {"pending", "not_connected"}:
        problems.append(f"host status is {status}")
    if collection is None:
        problems.append("collection_db not configured")
    elif not collection.exists():
        problems.append(f"collection_db missing on disk: {collection}")

    anki_tool: dict[str, Any] = {
        "reachable": bool(collection and collection.exists()),
        "app_running": anki_running(),
        "collection_db": collection,
        "profile_dir": profile,
        "install": anki.get("install"),
    }
    if not anki_tool["reachable"]:
        anki_tool["detail"] = "collection database missing"

    obsidian_tool: dict[str, Any] = {
        "reachable": bool(vault and vault.is_dir()),
        "vault": vault,
    }
    if not obsidian_tool["reachable"]:
        obsidian_tool["detail"] = "vault directory missing" if vault else "vault not configured"

    zotero_tool = zotero_api(api)
    zotero_tool["data_dir"] = data_dir
    if data_dir is None:
        zotero_tool["data_dir_detail"] = "not configured on this host"
    elif not data_dir.is_dir():
        zotero_tool["data_dir_detail"] = "path missing"

    return {
        "ok": not problems,
        "device_id": did,
        "label": cfg.get("label", did),
        "kind": cfg.get("kind", "host"),
        "status": status,
        "hostname": _hostname(),
        "platform": platform.system().lower(),
        "anki": anki_tool,
        "zotero": zotero_tool,
        "obsidian": obsidian_tool,
        "captures": capture_devices(reg),
        "problems": problems,
        "profile_dir": profile,
        "collection_db": collection,
        "obsidian_vault": vault,
    }


def require_collection_db(device_id: str | None = None) -> Path:
    info = resolve(device_id)
    db = info.get("collection_db")
    if not info.get("ok") or not isinstance(db, Path):
        parts = [
            f"Cannot resolve Anki collection (device={info.get('device_id')!r}, host={info.get('hostname')!r}).",
            *(info.get("problems") or []),
            info.get("hint") or "",
            f"Known devices: {', '.join(info.get('known_devices') or [])}",
            f"Edit: {DEVICES_FILE}",
        ]
        raise SystemExit("\n".join(p for p in parts if p))
    return db


def _stringify(info: dict[str, Any]) -> dict[str, Any]:
    def conv(value: Any) -> Any:
        if isinstance(value, Path):
            return str(value)
        if isinstance(value, dict):
            return {k: conv(v) for k, v in value.items()}
        if isinstance(value, list):
            return [conv(v) for v in value]
        return value

    return conv(info)


def main() -> None:
    import argparse

    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--device", default=None, help="Force host id from devices.json")
    ap.add_argument("--json", action="store_true", help="Print JSON")
    args = ap.parse_args()
    info = _stringify(resolve(args.device))
    if args.json:
        print(json.dumps(info, indent=2))
        return

    print(f"device:   {info.get('device_id')} ({info.get('label')})")
    print(f"status:   {info.get('status')}")
    print(f"hostname: {info.get('hostname')}")
    print(f"ok:       {info.get('ok')}")
    anki = info.get("anki") or {}
    zotero = info.get("zotero") or {}
    obsidian = info.get("obsidian") or {}
    print(f"anki:     reachable={anki.get('reachable')} app_running={anki.get('app_running')}")
    print(f"          {anki.get('collection_db')}")
    print(f"zotero:   reachable={zotero.get('reachable')} {zotero.get('detail', '')}")
    print(f"          data_dir={zotero.get('data_dir')}")
    print(f"obsidian: reachable={obsidian.get('reachable')} {obsidian.get('vault')}")
    for cap in info.get("captures") or []:
        print(f"capture:  {cap.get('device_id')} reachable={cap.get('reachable')} status={cap.get('status')}")
    if info.get("problems"):
        print("problems:")
        for problem in info["problems"]:
            print(f"  - {problem}")
    if info.get("hint"):
        print(f"hint:     {info['hint']}")


if __name__ == "__main__":
    main()
