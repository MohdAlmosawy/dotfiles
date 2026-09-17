---
name: odoo-small-tasks-sprint-prep
description: >-
  Prepares the Odoo Small Tasks next-sprint pack on live: asks developer
  capacity each run, selects Backlog tasks, writes Discovery and Stories, tags
  ready + next sprint, and does not assign developers. Use when the user is the
  Small Tasks technical lead preparing next sprint, building a sprint pack,
  writing Discovery/Stories for backlog handoff, or asks how many pack tasks
  remain.
---

# Odoo Small Tasks sprint prep

Technical-lead workflow for **preparing** Small Tasks for the next sprint. Output is written specs + tags on live `project.task`. Capacity is how many tasks to prepare, **not** who gets assigned.

This is **not** the weekly canvas (`odoo-small-tasks-weekly`). Do not assign `user_ids`. Do not change `stage_id` / `dev_stage_key`. Do not write Arch (Major only). Do not commit. Do not bump module versions.

Live source: `salamgas.odoo.com` via Odoo MCP. Scope every query with `is_odoo_small_task = True` and `dev_stage_key = backlog`. Look up tag ids by name each run — fallbacks in [reference.md](reference.md).

## When this is a new pack vs a continue

**New pack** (user says prepare next sprint / sprint pack / classify backlog for the sprint): start at step 1.

**Continue** (user says `lets do TASK_ID`, remaining count, or the pack is already locked in this chat): skip capacity and selection. Resume the write loop.

## 1. Ask capacity every new pack

Ask the user about **each developer’s capacity** every time a new pack starts. No fixed roster. No default seat counts. No default for Sayed overflow vs committed.

Ask, in one message:

1. Who is in this sprint (names they give — do not assume Ameen / Kareem / Dahab / Sayed)?
2. How many seats for each name (committed vs overflow, if they distinguish)?
3. Pack size = sum of **committed** seats they name. Overflow is extra only after the committed pack is clean specs.

If they already answered capacity in this chat, do not re-ask.

## 2. Load live backlog

Pull `project.task` where `is_odoo_small_task` and `dev_stage_key = backlog`. Attach ticket, department family, tags, assignees, Discovery emptiness, story count. See [reference.md](reference.md).

Then ask: **already-assigned Backlog tasks — in or out?** Group by assignee. Default is not “skip Ahmed”. Wait for the user. Hands-off tasks are not specced, not tagged, not used as seats.

## 3. Select the pack

Credit existing `ready` seats **only** when the spec (or ticket) is actually writable. A `ready` tag on an empty one-liner is not a seat — strip `ready`, tag `Need Clarification`.

Already-tagged `next sprint` that we can spec still consume a seat; write their Discovery/Stories if empty.

Fill seats in this order:

1. Credit valid `ready` / writable `next sprint`.
2. Clear **tails** (departments with 1–2 backlog items) that pass Rule 1.
3. Oldest clear tasks in large families, **cap 4 per family** including already-credited seats. Large families: Call Center, Finance, Logistics, Retail.
4. Identify overflow only after the committed pack is  clean writable specs.

**Rule 1 wins over age.** If Discovery + Stories cannot be written from the ticket + code without requester/management contact, it is out: tag `Need Clarification`. Do not invent a spec.

Stops (out of the pack, do not take a seat):

- `Need Call` — already judged that someone must get on a call
- `Need Clarification` after we confirm we cannot spec
- Assigned hands-off (from step 2)
- Work that is actually a product / Major (second epic, more than about one developer-week)
- Empty tickets with no screen, menu, model, or record

Not automatic stops:

- The `Major Project` tag — evaluate; escalate only when the work is actually Major
- Config / data / access / Excel — in if the request is clear
- Guidance tickets — in if they are a build

One-week / no second epic: if one developer cannot finish it in about a week without another epic, it stays out.

Propose the numbered pack. Grill **selection** only when rules conflict or a seat is a judgement. Lock the list with the user before writing.

## 4. Write loop

After lock:

- **No hole** → write Discovery + Stories + tags immediately. Do not wait for `lets do TASK_ID`.
- **Real hole** → stop and grill **that task only**, then write or tag `Need Clarification`. Then continue.
- User names an id (`lets do 326854`) → do that one next.

A real hole is a missing product rule that changes the spec and cannot be locked from the ticket + current code. Do not grill naming, style, or locks already settled in this chat.

Per task:

1. Read the task, ticket, chatter, and the code path the ticket implies.
2. Decide: write / grill / `Need Clarification` / cancel-obsolete.
3. If writing: MCP `validate_write` then **immediate** `execute_approved_write` for Discovery + `ready` + `next sprint`. Then create stories the same way. Confirm `user_ids` stays empty.
4. Chat: task id, what was locked, story ids, remaining count.

If the token expires, re-validate then execute. Do not leave a validated write unexecuted.

`Need Clarification`: tag 74 (lookup by name), leave Discovery/Stories empty, optionally draft a requester message for the **user** to post. Do not post as the agent unless asked.

Cancelled / obsolete: do not force a spec; say why and drop the seat.

## 5. Discovery and Stories

Write HTML (`<p>`, `<ul><li>`, `<strong>`). Match the form placeholders — see [reference.md](reference.md).

| Field | Content |
|---|---|
| `req_discovery_normalization` | Ticket rewritten: who, flow, success |
| `req_discovery_functional_scope` | In scope / out of scope. Name modules and records. |
| `req_discovery_readiness_check` | Why this is speccable now, or the one missing fact |
| `req_discovery_effort_signal` | Small/Medium/Large + confidence + driver |
| `req_discovery_business_risks` | What breaks if we get the lock wrong |

Stories on `project.task.story`: `epic_task_id`, `sequence` (10, 20, …), `role`, `intent`, `value`, `technical_notes`, `complexity` (`s`/`m`/`l`), `points` as a **string** (`1`/`2`/`3`/`5`/`8`). Usually 2–4 stories. No Unplanned story. `technical_notes` name the module, method, and a demo record when we have one.

Tags on every written pack task: **both** `ready` and `next sprint`.

## Do not

- Assign developers or “reserve” a seat with `user_ids`
- Move the task out of Backlog
- Write Arch fields
- Treat last sprint’s 25 / Ameen 10 / Kareem 10 / Dahab 5 as defaults
- Grill every product lock when the ticket + code already decide it
- Reopen a lock the user said to leave
- Credit a `ready` tag that has no writable spec
- Use `Need Call` as a hint — it is a stop
- Overwrite the weekly canvases
- Commit, or bump `__manifest__.py` `version`
