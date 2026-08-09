---
name: dev-story-workflow
description: >-
  Runs the Salam Odoo handoff story loop (Small task / Major project): explore
  story, set In Progress, timer, brief grill, implement, smoke, finalize, Confirm
  Time Spent paste text, then mark story Done only when acceptance is met. Use
  when the user invokes story workflow, starts or finishes a handoff story,
  needs Confirm Time Spent copy, or asks how to work the next story.
disable-model-invocation: true
---

# Dev Story Workflow

Orchestrate one **handoff** work slice (Major or Small). The human owns the Odoo timer UI; the agent drives grill → implement → verify → closure text, and updates story state in Odoo only when asked.

## Product facts (do not invent)

| Fact | Reality |
|------|---------|
| Where | Timer + Confirm Time Spent live on **`is_odoo_dev_handoff`** tasks, not requirement epics |
| Story picker | Only when handoff is **In Progress** and has sized (non-Unplanned) stories |
| Empty Stories | Logs to **Unplanned** — avoid unless truly out of plan |
| **Blocked ?** | Flag on the **timesheet line** only — does **not** set story `state=blocked` |
| Story states | `ready` → `in_progress` → `done` / `blocked` — **manual**; timer never changes them |
| Description | Required on handoff stop |
| Major vs Small | Major: clone epic stories — use them. Small: often no stories — description-only is fine |

## Phases

Track progress in the reply (copy and update):

```
Story workflow:
- [ ] 1 Explore
- [ ] 2 Story In Progress
- [ ] 3 Timer started (human)
- [ ] 4 Grill / lock scope
- [ ] 5 Implement
- [ ] 6 Smoke / test
- [ ] 7 Finalize checklist
- [ ] 8 Stop timer + Confirm Time Spent (human)
- [ ] 9 Story state (Done / Blocked / leave In Progress)
```

### 1. Explore

- Identify handoff task + story id (or Small with no story).
- Read intent, value, technical notes, acceptance from plan/epic.
- Restate in 2–3 lines: **done looks like** / **out of scope**.
- Suggest a short **chat title** if starting fresh (agents cannot rename chats).

### 2. Story → In Progress

- Ask human to set story **In Progress**, or write via Odoo MCP when they ask (`state=in_progress`).
- Skip if Small has no sized stories.

### 3. Timer start (human)

- Human: **Start Development** or **Start** on the handoff.
- Prefer **slice timers** when switching stories or hitting a block mid-day.
- Agent does not click the timer.

### 4. Brief grill / lock scope

- Lock acceptance, tip-of-chain / deps, and non-goals before coding.
- Skip only for trivial chores; for AI/epic work, grill is mandatory.
- Prefer `grill-me` / plan docs when the user wants a deep lock.
- Do **not** implement until scope is locked (or user explicitly says skip grill).

### 5. Implement

- Change only what the story requires; follow repo `AGENTS.md`.
- Never bump module `version` in manifests.
- Never commit unless the user explicitly asks (then use `commit-comment` if invoked).

### 6. Smoke / test

- Module install/upgrade + the affected workflow only (no repo-wide test runner).
- Report pass/fail against the story acceptance, not “looks fine”.

### 7. Finalize checklist

Only proceed to stop-timer copy when:

- [ ] Acceptance for **this** story is met (or explicitly parked)
- [ ] Unrelated workflows untouched
- [ ] Working tree intentional (commits ready or clean WIP plan)
- [ ] Follow-ups are **other stories / plan notes**, not hidden leftover in this story

### 8. Stop timer → Confirm Time Spent (human)

When the user is ready to stop (or asks for the form), output paste-ready fields:

```markdown
**Hours Spent?** `<as shown — do not invent>`

**Stories?** `<id> — <short intent>` (or empty only if truly Unplanned)

**Blocked?** `No` | `Yes` ← timesheet flag only; if Yes, say why in description

**Describe your activity...**
<1–3 sentences: what shipped, smoke result, parked follow-ups with story ids>
```

Rules:

- Prefer the story that was worked; do not dump time on Unplanned by default.
- If work was blocked externally: **Blocked ?= Yes** on the timesheet **and** offer to set story `state=blocked` separately.
- Do not claim Done in the description unless step 9 will mark Done.

### 9. Story state after logging

| Outcome | Story state |
|---------|-------------|
| Acceptance met, smoke ok, no hidden WIP | **Done** (only when user confirms or asks to mark done) |
| Waiting on dependency / decision | **Blocked** + short note |
| More work on same story | leave **In Progress** |
| Pausing cold | **Ready** optional |

Never mark Done because the timer stopped. Never mark Done if commits/smoke/acceptance are incomplete.

## Agent role by phase

| Phase | Agent does | Human does |
|-------|------------|------------|
| Explore / grill | Read story, lock scope, checklist | Confirm locks |
| Implement / smoke | Code, upgrade, verify | Review, run UI checks as needed |
| Timer / Confirm | Draft Hours/Stories/Blocked/Description | Start/Stop, Save timesheet |
| Done | MCP write `state=done` when asked | Approve mutation if gated |

## Entry modes

- **Start story** — user gives story id/URL or “next story”: run phases 1→4, then wait for implement go-ahead.
- **Continue** — resume checklist from last unfinished phase.
- **Closing** — run 7→9; produce Confirm Time Spent text; mark Done only if truly done and requested.
- **Next story?** — if previous not Done/logged, say so; else point at next sequenced story.

## Anti-patterns

- Implementing before grill on non-trivial stories
- Marking story Done from the timer stop alone
- Treating **Blocked ?** as story `blocked`
- Logging to Unplanned when a sized story exists
- Bundling follow-up scope into “Done” instead of a new story
- Auto-committing or auto-writing Odoo without an explicit ask
