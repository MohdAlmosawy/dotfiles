---
name: zotero
description: >-
  Reads and updates the UOB MSc Zotero library through the local API: items,
  collections, PDFs, and citations. Use when the user mentions Zotero, a
  citation, a library PDF, or a Zotero collection. Does not write Obsidian
  notes or Anki cards.
---

# Zotero

Source of record for papers: the PDF and the citation. Reading notes, knowledge-base notes, and Anki cards are later exits owned by `obsidian` and `anki`.

## Before any read or write

1. Run `python ~/.cursor/skills/devices/scripts/device.py --json`.
2. Use the host's `zotero.api` (default `http://127.0.0.1:23119`). Local library user id is `0`.
3. If Zotero is not reachable, say so. `403` means the app is open and **Allow other applications on this computer to communicate with Zotero** is off. Connection refused means the app is not running.
4. Propose creates and edits. Write only after the user says go, or when the same message already says to do it.

Read:

```bash
curl -sS 'http://127.0.0.1:23119/api/users/0/collections?limit=50'
curl -sS 'http://127.0.0.1:23119/api/users/0/items?limit=25&format=json'
```

Item keys and titles are enough unless the user asks for a full record. Do not dump every attachment.

## Library rules

- List collections from the API. Do not assume a fixed tree. Names change.
- A new paper is a Zotero item first. Do not create an Obsidian stub for it.
- Do not write vault files. If the user wants a reading note, stop after the Zotero item exists and hand the item key to the `obsidian` skill.
- Do not create Anki cards.
- The data directory from `devices` is for reachability and backups, not a second catalog. Prefer the API while Zotero has the database open.

## Writes

Use the local API (`POST` / `PATCH` / `DELETE` under `/api/users/0/`). After a write, re-read the item and report its key and title. Tell the user to let Zotero sync if they use another host.
