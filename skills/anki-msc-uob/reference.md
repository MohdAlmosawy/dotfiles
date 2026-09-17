# Anki MSc UOB — reference

## Devices and paths

Canonical registry: [devices.json](devices.json). Resolver: `scripts/device.py`.

**Never treat one machine’s path as universal.** Resolve first:

```bash
python ~/.cursor/skills/anki-msc-uob/scripts/device.py --json
```

### Active: `alsalam-work` (this device today)

| What | Path |
|------|------|
| Hostname match | `Ubuntu24` |
| Anki install | snap |
| Profile | `~/snap/anki-desktop/common/User 1` |
| Collection | `~/snap/anki-desktop/common/User 1/collection.anki2` |
| Media / backups | `…/collection.media` · `…/backups/` |
| Obsidian vault | `~/Desktop/obsidian/6 AI-Master UOB` |
| Semester courses | `…/01 MSc UOB/Semester 1 - 2026/` |

### Pending: `personal-laptop`

Fill on first setup in `devices.json`:

1. `match.hostnames` — run `hostname` on that machine  
2. `anki.install` — `native` / `flatpak` / `snap` / `windows` / `macos`  
3. `anki.profile_dir` + `anki.collection_db` — typical locations:
   - Linux native: `~/.local/share/Anki2/<Profile>/collection.anki2`
   - Flatpak: `~/.var/app/net.ankiweb.Anki/data/Anki2/<Profile>/`
   - Windows: `%APPDATA%\Anki2\<Profile>\`
   - macOS: `~/Library/Application Support/Anki2/<Profile>/`
4. `obsidian.vault`  
5. Set `status` → `active`  
6. Sync AnkiWeb once **before** any agent writes  

Optional per-machine overrides (not required): `devices.local.json` next to `devices.json` (same shape under `devices`). Env overrides: `ANKI_MSC_DEVICE`, `ANKI_MSC_DB`.

## Courses

| Code | Title | Anki course tag | Typical lecture day |
|------|-------|-----------------|---------------------|
| ITML 601 | Advanced AI & NLP | `course::601` | Monday |
| ITML 602 | Machine Learning | `course::602` | Wednesday |
| ITML 603 | Research Methodology | `course::603` | Tuesday |

601 roadmap: W1–7 `phase::symbolic` (search → KR → fuzzy → expert/HMM); W8–14 `phase::nlp` (embeddings → transformers → RAG); W15 project.

## Preset IDs and intent

| Preset | id | Role |
|--------|-----|------|
| Default | `1` | Stock fallback — leave alone |
| CAIE Main | `1771010340056` | Pre-MSc cert — leave alone |
| Long Term Retention | `1772093537700` | **Daily driver** |
| Exam Mode | `1771586070588` | Temporary exam overlay |

### Long Term Retention (daily)

- Learn / relearn: `10m` / `10m`
- New/day: `30` · Reviews: `9999`
- Desired retention: `0.90` · Max interval: `36500`
- Bury new + review + interday siblings: on
- Review order: Retrievability ascending
- FSRS-6 params: Anki stock 21-weight defaults
- Timer: off

### Exam Mode (overlay)

- Learn / relearn: `10m` / `10m` (never `1d`)
- New/day: `50` · Reviews: `9999`
- Desired retention: `0.94` · Max interval: `21`
- Reviews before new cards
- Timer on (75s, stop on answer)
- FSRS-6 stock 21 weights
- Use ~1–2 weeks before midterm/finals, then revert to LTR

Deck `kind` protobuf: `KindContainer.normal.config_id` = preset id. All `MCs*` decks should use LTR unless intentionally on Exam Mode.

## Tag catalog

### Fixed layers

- `course::601` | `course::602` | `course::603`
- `week::01` … zero-pad 2 digits
- `lec::01` … lecture number within course
- `phase::symbolic` | `phase::nlp` | (603 may use `phase::methods` later if needed)

### Topics (601 — extend as syllabus progresses)

Current:

- `topic::ai-foundations`
- `topic::agents`
- `topic::symbolic-ai`
- `topic::search-foundations`

Planned syllabus-aligned:

- `topic::adversarial-search`
- `topic::knowledge-rep`
- `topic::fuzzy-logic`
- `topic::text-preprocess`
- `topic::statistical-nlp`
- `topic::sequence-labeling`
- `topic::embeddings`
- `topic::transformers`
- `topic::contextual-lms`
- `topic::downstream-nlp`
- `topic::rag-llms`
- `topic::ai-ethics`

Add 602/603 topics when those decks start (e.g. `topic::supervised`, `topic::research-design`).

### Types

- `type::def` — definition / term
- `type::contrast` — X vs Y
- `type::why` — reason / implication
- `type::formula` — formal notation
- `type::algo` — procedure / steps

### Flags

- `flag::weak` | `flag::exam-core` | `flag::teach`

## Browser searches

| Goal | Search |
|------|--------|
| This week | `tag:week::01` |
| Weak topic | `tag:topic::symbolic-ai` or `tag:flag::weak` |
| Midterm (601) | `tag:course::601 tag:phase::symbolic` |
| Whole course exam | `tag:course::601` |
| Definitions | `tag:type::def` |
| Teaching candidates | `tag:flag::teach` |

## Deck placement rules

| Content | Deck |
|---------|------|
| AI taxonomy, agents, policy, symbolic vs non-symbolic | `601-NLP :: 00) Introduction` |
| State space, node vs state, heuristics, A* | `601-NLP :: 01) Search Foundations` |
| Later syllabus blocks | matching `NN) Title` subdeck |

## Technical notes

- Schema v18: `deck_config.config`, `decks.common`, `decks.kind` are protobuf blobs.
- Deck hierarchy in DB uses `\x1f` separators (UI shows `::`).
- FSRS is on globally; `fsrsShortTermWithStepsEnabled` is false — keep steps same-day.
- Old wiped collection left many unused rows in `tags` table; note tags are source of truth. Anki “Check Database” can prune unused tag names.
- Note type in use: Basic (optional reversed card). Some notes may reference mid that displays as that type.

## FSRS-6 default weights (21)

```
0.212, 1.2931, 2.3065, 8.2956, 6.4133,
0.8334, 3.0194, 0.001, 1.8722,
0.1666, 0.796, 1.4835, 0.0614, 0.2629,
1.6483, 0.6014, 1.8729, 0.5425,
0.0912, 0.0658, 0.1542
```
