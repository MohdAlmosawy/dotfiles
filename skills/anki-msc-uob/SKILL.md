---
name: anki-msc-uob
description: >-
  Audits and maintains Sayed's UOB MSc Anki setup (decks, FSRS presets, hierarchical
  tags, card placement). Use when the user mentions Anki, Anki cards, deck options,
  Long Term Retention, Exam Mode, Anki tags, flashcards for ITML601/602/603, or
  checking/updating the MSc Anki collection.
---

# Anki MSc UOB

Personal Anki system for University of Bahrain MSc (Machine Learning & Computational Intelligence). Obsidian vault is the understanding layer; Anki is spaced retrieval only.

Preset values, tag catalog, syllabus map: [reference.md](reference.md).  
Device paths: [devices.json](devices.json) (resolved by [scripts/device.py](scripts/device.py)).

## Multi-device (required)

Anki **content** syncs via AnkiWeb. **Filesystem paths differ** per machine — never assume one `DEFAULT_DB`.

| Device id | Machine | Status |
|-----------|---------|--------|
| `alsalam-work` | AlSalam work PC (hostname `Ubuntu24`, snap Anki) | active |
| `personal-laptop` | Personal laptop | pending — fill paths on first setup |

**Resolve order:** `--db` / `ANKI_MSC_DB` → `ANKI_MSC_DEVICE` → hostname match in `devices.json` → optional `devices.local.json` overrides.

Before any write on a new device: confirm resolved path, confirm AnkiWeb sync is healthy, then backup. When adding a device, edit `devices.json` (hostnames + `anki.collection_db` + Obsidian vault); do not hardcode paths in scripts.

```bash
python ~/.cursor/skills/anki-msc-uob/scripts/device.py
python ~/.cursor/skills/anki-msc-uob/scripts/inspect_cards.py
```

## Success hierarchy (never optimize against this)

1. **Short-term** — digest week’s concepts; know strong vs weak areas  
2. **Short–mid** — exam readiness (midterm ~W8, finals early Jan)  
3. **Long-term** — retention for thesis / PhD / life  

## Study workflow

- **Mon / Tue / Wed:** one lecture each (601 / 603 / 602) → cards same night or next day  
- **Thu:** BOOX → Obsidian; light card improve; mark `flag::teach` if teachable  
- **Fri:** deep study weak topics → few new cards, small edits; use `flag::weak`  
- Pipeline: `Course Material/` → `Lectures/` → `02 Knowledge Base/` → **Anki** → optional Teaching script  

Week starts **Saturday**. Obsidian vault path comes from the **resolved device** (not a hardcoded work-PC path).

## Collection access (required safety)

1. Resolve device via `scripts/device.py` — refuse writes if `status=pending` or DB path missing.
2. DB is `collection.anki2` under that device’s profile (schema v18; configs = protobuf).
3. **Before any write:** backup under that profile’s `backups/`, ensure Anki is **not running**. Prefer graceful quit.
4. Read-only inspect is fine while Anki is open (`mode=ro` / `immutable=1`).
5. Register SQLite collation `unicase` or avoid `ORDER BY` on unicase columns.
6. Do **not** dump full note backs unless asked; prefer scoped summaries.
7. After writes: bump `col.mod`, set `usn=-1` on changed rows; tell user to reopen Anki (+ sync if multi-device).

## Deck layout

```
MCs
└─ 601-NLP          (add 602-ML, 603-Research the same way)
   ├─ 00) Introduction
   └─ 01) Search Foundations
   └─ … one subdeck per syllabus topic block
```

- **Decks** = study click-targets / lecture-topic placement  
- **Tags** = cross-cutting filters for the success hierarchy  
- Place cards by **content topic**, not by when you happened to add them  

Default preset on MSc decks: **Long Term Retention**. Switch to **Exam Mode** only ~1–2 weeks before midterm/finals, then switch back.

## Tag scheme (required on every new note)

Always set:

| Layer | Example | Role |
|-------|---------|------|
| `course::` | `course::601` | Course / exam filter |
| `week::` | `week::01` | Short-term digest window |
| `lec::` | `lec::01` | Capture batch |
| `phase::` | `phase::symbolic` or `phase::nlp` | Midterm vs final for 601 |
| `topic::` | `topic::agents` | Weak-area + Fri drills |
| `type::` | `type::def` \| `contrast` \| `why` \| `formula` \| `algo` | Recall mode |

Optional flags (mutable):

- `flag::weak` — Fri / struggling  
- `flag::exam-core` — must-know for next exam  
- `flag::teach` — YouTube / teaching candidate  

Anki tag string format: leading + trailing space, tags space-separated:  
`" course::601 week::01 … "`

Useful searches: see [reference.md](reference.md#browser-searches).

## When user asks to check setup

1. Run device resolve; state **which device** and DB path.  
2. Confirm Anki running state; use read-only DB access.  
3. Report: deck tree + card counts, preset assignment, preset keys vs reference, tag coverage, placement mismatches.  
4. Flag issues only; fix when asked (or when user says go ahead).

## When user asks to update tags / place cards

1. Resolve device; abort if pending/unresolved.  
2. Scoped-list affected notes (ids, deck, tags, short front).  
3. Propose tag/deck changes aligned to scheme + syllabus topics.  
4. On approval (or “go”): close Anki → backup on **this device’s** profile → update `notes.tags` and/or `cards.did` → upsert `tags` → bump `col.mod`.  
5. Verify with inspect script; remind user to **AnkiWeb sync** if they also use another device.

## Card quality norms

- Atomic, checkable recall — not whole KB notes.  
- Prefer Basic (optional reverse) only when reverse is meaningful (e.g. term ↔ definition).  
- After new lecture: add cards + full tag set; fix placement if content belongs in another subdeck.  
- Do not invent new tag roots (`course`, `week`, `lec`, `phase`, `topic`, `type`, `flag`) without user agreement.

## Do not

- Hardcode AlSalam/snap paths as the only DB location.  
- Write on a `pending` device until paths are filled and sync is confirmed.  
- Rewrite presets without explicit ask.  
- Use Exam Mode as daily driver.  
- Learning steps ≥ 1 day while FSRS is on.  
- Store secrets or dump entire collection text into chat unsolicited.
