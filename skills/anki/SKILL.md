---
name: anki
description: >-
  Maintains the UOB MSc Anki collection: decks, hierarchical tags, FSRS presets,
  and card placement. Use when the user mentions Anki, flashcards, decks, FSRS,
  Long Term Retention, Exam Mode, or tags for ITML 601, 602, or 603. Does not
  own the weekly schedule or the Obsidian vault.
---

# Anki

Spaced retrieval for the University of Bahrain MSc. The vault holds understanding. Cards are atomic recall only.

Presets, tag catalog, syllabus map: [reference.md](reference.md).

## Before any read or write

1. Run `python ~/.cursor/skills/devices/scripts/device.py --json`.
2. Refuse writes if the host is unresolved, pending, or not connected, or the collection path is missing.
3. Read-only inspect is allowed while Anki is open.

```bash
python ~/.cursor/skills/anki/scripts/inspect_cards.py
```

## Writes

Propose the change (note ids, deck, tags, short front). Write only after the user says go, or when the same message already says to do it.

Before a write:

1. Quit Anki. `app_running` true blocks the write. Snap Anki's command line contains `anki-desktop`; native Anki contains `anki-bin` or `/bin/anki`.
2. Back up under that profile's `backups/`.
3. Update `notes.tags` and/or `cards.did`. Upsert `tags`. Bump `col.mod`. Set `usn=-1` on changed rows.
4. Re-run the inspect script. Tell the user to reopen Anki and sync AnkiWeb if they use another host.

Writing while Anki is open zeroed the collection once. Register SQLite collation `unicase` or avoid `ORDER BY` on unicase columns. Do not dump full note backs unless asked.

## Deck layout

```
MCs
└─ 601-NLP
   ├─ 00) Introduction
   └─ 01) Search Foundations
   └─ … one subdeck per syllabus topic block
```

Same pattern for `602-ML` and `603-Research`. Decks are study click-targets. Tags are cross-cutting filters. Place cards by content topic.

Default preset on MSc decks: **Long Term Retention**. Switch to **Exam Mode** only for the one to two weeks before a midterm or final, then switch back. Leave the Default and CAIE Main presets alone.

## Tags required on every new note

| Layer | Example |
|-------|---------|
| `course::` | `course::601` |
| `week::` | `week::01` |
| `lec::` | `lec::01` |
| `phase::` | `phase::symbolic` or `phase::nlp` |
| `topic::` | `topic::agents` |
| `type::` | `type::def`, `contrast`, `why`, `formula`, or `algo` |

Optional: `flag::weak`, `flag::exam-core`, `flag::teach`.

Anki tag string: leading and trailing space, tags space-separated.

## Card norms

- Atomic and checkable. Not a whole knowledge-base note.
- Basic, with an optional reverse only when the reverse is meaningful.
- Do not invent tag roots (`course`, `week`, `lec`, `phase`, `topic`, `type`, `flag`) without agreement.

## Do not

- Hardcode a host path. Use the `devices` skill.
- Rewrite presets unless asked.
- Use Exam Mode as the daily driver.
- Set learning steps of one day or more while FSRS is on.
- Edit the vault or the Zotero library from this skill.
