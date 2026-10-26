---
name: obsidian
description: >-
  Files and edits notes in the AI-Master UOB Obsidian vault: inbox, lectures,
  knowledge base, reading notes, thesis, experiments, teaching scripts, and
  UOB LaTeX assignments. Use when the user mentions that vault, a lecture
  note, the knowledge base, a reading note, the LaTeX template, Times New
  Roman, or where a markdown note belongs. Does not edit Anki or Zotero.
---

# Obsidian

Understanding layer for the University of Bahrain MSc. Vault path comes from the `devices` skill. Do not hardcode it.

```bash
python ~/.cursor/skills/devices/scripts/device.py --json
```

Refuse writes when the vault is not reachable. Propose the note path and the edit. Write only after the user says go, or when the same message already says to do it.

Folder map and the lecture pipeline: [reference.md](reference.md). The weekly calendar lives in the `journey` skill.

## Rules

- `00-Inbox` is the filing queue for captures. It is not proof the BOOX is online. File inbox notes into a lecture note or a knowledge-base note, then they should not linger.
- Lecturer files stay in `Course-Material/`. The student's write-up is `Lectures/L01 - ….md`.
- Folder names have no spaces. Use hyphens, and write `&` as `and`.
- A paper's source of record is the Zotero item. Create `03-Papers/Reading-Notes` only when the user is reading that paper, and store the Zotero item key on the note. Do not create a stub for every library item.
- Knowledge-base notes and teaching scripts are later exits. Do not create them from a paper unless the user asks.
- Do not create or edit Zotero items. Hand that to the `zotero` skill.
- Do not open `collection.anki2`. Hand cards to the `anki` skill.
- Do not invent new top-level vault folders.

## Teaching

`05-Teaching-and-YouTube` is an optional exit: Ideas, then Scripts, then Published. A concept marked worth teaching can land in Ideas. This is not a separate tool.
