---
name: devices
description: >-
  Resolves the UOB MSc host (personal laptop, AlSalam PC) and reports whether
  Anki, Zotero, the Obsidian vault, the LaTeX toolchain, and the BOOX are
  reachable. Use when the user mentions the personal laptop, AlSalam, BOOX,
  which machine, LuaLaTeX, LaTeX Workshop, or a path to the Anki collection,
  Zotero data directory, or AI-Master vault. Does not sync, import, or edit
  those tools.
---

# Devices

Registry of machines for the University of Bahrain MSc. Paths differ per host. Tool content syncs on its own (AnkiWeb, Zotero sync, vault copies). This skill only identifies the host and reports reachability.

Run this before any read or write in `anki`, `obsidian`, or `zotero`.

```bash
python ~/.cursor/skills/devices/scripts/device.py --json
```

Refuse tool writes when `ok` is false, the host `status` is `not_connected` or `pending`, or the tool you need is not reachable.

## What reachability means

| Tool | Reachable when |
|------|----------------|
| Obsidian | Vault directory exists |
| Anki | `collection.anki2` exists. Also report whether the app is running |
| Zotero | Local API ping at `http://127.0.0.1:23119/connector/ping` returns that Zotero is running. `403` means the app is up and the local API is off |
| BOOX | Registry status is `connected` and a path is set. Today it is `not_connected`. Inbox files are not a signal |
| LaTeX | `lualatex`, `biber`, and `latexmk` are on `PATH`, and `90-Resources/UOB-LaTeX/fonts/` in the vault contains `Times.TTF`, `Timesbd.TTF`, `Timesbi.TTF`, and `Timesi.TTF`. Also reports TeXstudio when that is the host editor, and whether Cursor has `james-yu.latex-workshop`. A missing toolchain does not set host `ok` to false |

The BOOX is a capture device. It is never chosen as the current host by hostname.

## Resolve order

`MSC_DEVICE` or `ANKI_MSC_DEVICE`, then hostname match in [devices.json](devices.json), then optional `devices.local.json` beside it. Collection override: `MSC_ANKI_DB` or `ANKI_MSC_DB`.

When adding a host, edit `devices.json` (hostname, Anki, Zotero, vault, LaTeX). The laptop editor is TeXstudio. The AlSalam PC editor is Cursor, with the LaTeX Workshop recipe `latexmk (lualatex)`. Do not hardcode one machine's paths in the other skills.

## Do not

- Sync AnkiWeb, import BOOX notes, or write the vault or the Zotero library.
- Treat `00-Inbox` as proof the BOOX is online.
- Invent a USB or sync path for the BOOX.
