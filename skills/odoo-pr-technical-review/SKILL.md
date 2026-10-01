---
name: odoo-pr-technical-review
description: >-
  Technical-review Odoo PRs for the Al-Salam Gas 16.0 addon monorepo using
  task/ticket for the business ask, then code/diff/AGENTS gates, minimal-diff
  blast radius, a fixed review report, then draft GitHub inline comments posted
  only after the user approves. Judges the code, not functional testing or UAT
  (those are a previous stage). Use when the user asks for a technical review,
  PR review of a Salam/Odoo PR, readiness to merge, or invokes
  odoo-pr-technical-review.
disable-model-invocation: true
---

# Odoo PR Technical Review

Review PRs against the **Al-Salam Gas Odoo 16.0 addon monorepo** (`live`). Standards live in repo **`AGENTS.md`** (and **`critical_overrides.md`** when shared/core methods are overridden). Do not restate those docs wholesale — enforce them as review gates.

This stage is a **code review**. Functional testing and UAT are done in a previous stage most of the time. Do not invent UAT results, do not ask for a UAT/functional re-test, and do not hold Approve on missing UAT evidence unless the user explicitly asks to include it.

The agent produces a **fixed report** (template below), then a **draft inline-comment pack** for GitHub. Do **not** post review comments to GitHub until the user explicitly approves which comments to publish.

## Contract fence (hard)

Applies always — including when launched from `odooer-day-ops` starter packs.
Full fence (all layers, not only git):
`~/.cursor/skills/odooer-day-ops/contracts.md`.

Obey **all** of: repo **`AGENTS.md`** (KISS, minimal diff, multi-company,
workflow isolation, scoped CSS, no unjustified `noupdate`, no secrets, menus /
groups conventions, …), **`critical_overrides.md`** when overriding owned
methods, user rules, and this skill.

- **Default role = review only.** Verdict + draft GitHub comments. No ship.
- **Permission:** Soft phrases are not approval. Explicit ask required for git
  commit/push/merge, GitHub review posts / `gh pr edit`, and Odoo writes.
  “Drop this from the PR” / “fix it” / “return to PR Ready” authorize only what
  they name — not commit/push.
- If the user asks for a code change after the verdict: edit → stop →
  **`commit-comment`** (commands only). Tell day-ops `needs commit plan` when
  this was an orchestrator handoff.
- **Never** bump module `version` in `__manifest__.py`.
- Prefer `git fetch` + `git show` / `gh` over checking out the PR branch onto
  the shared `live` worktree.
- When returning to day-ops: **Verdict line** (+ optional `needs commit plan` /
  `needs Odoo write approval` / worktree note).

## When to run

- User asks for technical review / PR review / merge readiness on this repo
- User pastes a task URL, ticket, or GitHub PR for Salam Odoo work
- User invokes this skill by name

## Inputs to gather (in order)

1. **Odoo task** — id, name, stage, description, linked ticket (scope only)
2. **Original ticket / chatter** — requester ask and scope signals. Ignore UAT/“please test this path” as review work.
3. **GitHub PR** — title, base branch, files, **all commits** (not tip only), review/bot comments, mergeability
4. **Repo truth** — `AGENTS.md`; `critical_overrides.md` if overrides touch owned methods
5. **Net diff vs intended production base** — usually `master` and/or stated merge target (`mirror`, etc.)

Use Odoo MCP / `gh` / `git` as available. Prefer reading sources over guessing.

## Review workflow

Copy and track:

```
PR technical review:
- [ ] 1 Business anchor
- [ ] 2 Claim → code
- [ ] 3 Diff blast radius (minimal necessary)
- [ ] 4 Base branch + full history
- [ ] 5 AGENTS / override gates
- [ ] 6 Bot/CI triage
- [ ] 7 Deploy path (install vs upgrade, seeds in the diff)
- [ ] 8 Fixed report
- [ ] 9 Draft inline comments → ask user → post only if approved
- [ ] 10 Suggest the Odoo "PR Needs Changes" note (Request changes only)
```

### 1. Business anchor

Restate the ask in 2–4 lines: **done looks like** / **out of scope**. Ignore PR marketing language when it conflicts with ticket/chatter. Use this only to judge whether the **code** implements the ask.

### 2. Claim → code

For each material claim (feature, fix, seed, ACL, upgrade path):

| Claim | Where in code | Implementation note | Gap? |

- Gaps **claim↔code** (wrong report, missing field, dead seed, broken contract) = findings.
- The diff **is** the evidence. Do not add Gaps for “no UAT print”, “no test plan”, or “please smoke this workflow”.
- In-PR XML/demo/seeds are reviewed as **code** (load risk, private APIs, `noupdate`, xml ids) — not as a substitute UAT script.

### 3. Diff blast radius (minimal necessary)

One top-level folder = one module.

- List modules touched and why each is required for the ask
- Flag **bundled / orthogonal** changes (sibling modules, “while here” fixes)
- Prefer **drop or separate PR** for orthogonal work unless user explicitly keeps it
- Check dependency claims: direct `__manifest__` deps vs transitive-only usage
- Shared-model changes must show **workflow isolation** (scope gate / filtered overrides)

### 4. Base branch + full history

- Confirm PR **base** (e.g. `mirror` vs `master`)
- Review **every commit** on the branch since divergence
- Note later commits that already address earlier bot/review comments
- Net diff vs `master` (or agreed production truth) after cleanup

### 5. AGENTS / override gates (spot-check, not essay)

Fail or flag when the **diff** violates review-critical rules:

- Never bump module `version` in `__manifest__.py`
- Forward `*args, **kwargs` / required args to `super()` on owned overrides (`critical_overrides.md`)
- No unjustified `noupdate="1"`
- Multi-company safety; no single-company assumptions
- CSS scoped; no global leakage
- Business logic in Python, not complex view attrs/domains
- Workflow isolation on shared models
- Custom groups imply `base.group_erp_manager` when adding security groups
- No secrets / customer data in the PR

There is no repo-wide test runner. Do not invent a functional test plan to “validate” the PR.

### 6. Bot / CI triage

Treat CodeRabbit / CI as a **checklist**, not a verdict:

- Already fixed in a later commit?
- Real bug / security / contract break vs style noise?
- Classify each open item: **blocker** / **follow-up** / **ignore (with reason)**

### 7. Deploy path

Answer from the **code** only:

- Install vs upgrade for touched modules (what lands in `data` vs `demo`)
- Seed/XML in the diff: xml ids, `noupdate`, demo-only vs production data
- Remaining GitHub Approve / merge target
- Post-merge smoke: **N/A** unless the user asks

## Verdict vocabulary

Use exactly one:

| Verdict | When |
|---------|------|
| **Approve** | Ask met in code, blast radius clean, no open code blockers |
| **Approve with follow-ups** | Ask met in code; non-blocking **code** gaps documented |
| **Request changes** | Must-fix before merge (**code** correctness, security, AGENTS breach, wrong blast radius) |
| **Blocked** | Missing task/PR access, cannot read diff, or unresolved external dependency |

Do not use Request changes, Blocked, or follow-ups for missing UAT/functional testing.

## Fixed report format (mandatory)

Emit the review **only** in this structure. Keep sections; use `None` or `N/A` when empty. Be concise.

```markdown
# Technical review — [PR #N / task id] [short title]

## Verdict
[Approve | Approve with follow-ups | Request changes | Blocked]

One sentence: why.

## Business ask
- Requester / source:
- Done looks like:
- Out of scope:

## Claim → code
| Claim | Code | Implementation | Gap |
|------|------|----------------|-----|
| … | … | … | none / … |

## Diff blast radius
- Modules touched:
- Required for the ask:
- Bundled / drop or split candidates:
- Deps note (direct vs transitive):

## Base & history
- PR base → head:
- Compared also to:
- Commits reviewed (count / notable):
- Bot items already fixed in later commits:

## AGENTS / override gates
- Pass / findings (bullets only):

## Bot / CI triage
| Item | Disposition | Notes |
|------|-------------|-------|
| … | blocker / follow-up / ignore | … |

## Blockers
- None
- or numbered must-fix **code** items

## Follow-ups (non-blocking)
- None
- or numbered **code** items (owner/suggestion optional)

## Deploy path
- Install/upgrade:
- Seed / XML in the diff:
- GitHub Approve / merge target:
- Post-merge smoke: N/A

## Test plan
- N/A
```

`## Test plan` stays in the template for parsers. Default **N/A**. Fill it only if the user explicitly asks for functional/UAT checks.

## 9. Inline GitHub comments (ask first, post only if approved)

After the fixed report, **always** propose a draft comment pack before touching GitHub review APIs.

### What to draft

From **Blockers** and material **Follow-ups** (and any user-flagged items), prepare **actionable** inline comments:

| # | Severity | File | Line (tip) | Draft body (concise) | Why |
|---|----------|------|------------|----------------------|-----|
| 1 | blocker / follow-up | path | N | … | … |

Rules for drafts:

- Prefer **one comment per finding**, anchored to the best tip-commit line (`gh` / `git show HEAD:path` with line numbers)
- Body: problem → why it matters → concrete fix ask (no AGENTS essay, no CodeRabbit paste dumps)
- Skip noise already fixed in a later commit, pure style nits, bot items classified **ignore**, and anything that is UAT/functional testing
- If a finding has no good line anchor, draft a **PR-level** review note instead of a fake inline

Also propose the **review event**:

| Verdict | Default `gh` review event |
|---------|---------------------------|
| Request changes | `REQUEST_CHANGES` |
| Approve with follow-ups | `COMMENT` (or `APPROVE` only if user says so) |
| Approve | `APPROVE` only if user says so |
| Blocked | do not post; explain gap |

### Ask the user (mandatory gate)

Stop and ask before posting. Present the table (or numbered drafts) and ask explicitly, e.g.:

- Post **all** draft comments?
- Post **only blockers** / a selected subset?
- Edit wording first?
- Skip GitHub comments this time?

Do **not** treat report delivery, “looks good”, or silence as approval to publish.

### Post only after approval

When the user approves (all or a subset):

1. Resolve **head SHA** and verify each `path`/`line` still exists on that commit
2. Create **one** PR review via `gh api repos/<owner>/<repo>/pulls/<n>/reviews` with approved inline `comments` (+ short summary body mirroring the agreed asks)
3. Return the review URL
4. If the API rejects a line anchor, fix the anchor or fall back to a PR-level comment for that item — do not silently drop blockers

Never: commit, push, merge, dismiss others’ reviews, or `gh pr edit` unless the
user explicitly asks for that named action. See **Contract fence** above.

### Report add-on (after step 8, before asking)

Append this section to the chat (after the fixed report; not inside the mandatory template if that would break parsers — prefer immediately below the report):

```markdown
## Proposed GitHub inline comments (not posted yet)
| # | Severity | File | Line | Draft |
|---|----------|------|------|-------|
| … | … | … | … | … |

**Review event if posted:** REQUEST_CHANGES | COMMENT | APPROVE

Reply with: post all / post #… / edit … / skip.
```

If Blockers and Follow-ups are both None, the table may be `None` and the ask can be skip.

## 10. Odoo "PR Needs Changes" note (suggest only)

Run after the GitHub review is posted when the verdict is **Request changes** (or the user says the task goes back to the developer). Suggest the text; the **user** submits it.

### What the wizard does (`salam_odoo_development`)

On a dev handoff task in **Technical Review**, the **PR Needs Changes** button opens the "Changes Needed" wizard (plain-text note, optional). **Send to Ready**:

1. Posts to task chatter: **"Technical review — changes needed"** + the note, notifying the task assignees.
2. Moves the task to **Ready** (branch and PR are reused).
3. Posts a top-level PR comment: `FYI : @coderabbitai` + blank line + the note. CodeRabbit is mentioned so it reads the note and replies.

It is fail-closed: if the GitHub post fails, the stage move rolls back. An empty note posts only the chatter title and nothing to GitHub.

### Purpose of the note

- **Developer:** one overall summary of what must change, pointing to the review for line-level detail.
- **CodeRabbit:** the **current** requirement. Scope often shifts after Discovery (chatter clarifications, testing feedback), and CodeRabbit otherwise judges against the stale PR description. State what changed, when, and the source.

### Content rules

- **Plain text.** Chatter escapes it: no markdown headers or tables, and backticks show literally. Short lines with `-` or `1.` work in both chatter and GitHub.
- Do **not** start with `FYI : @coderabbitai`; the wizard adds it.
- Do **not** paste the review report. Summarise and point to the GitHub review.
- Keep it to roughly 5–10 lines, in this order:
  1. One-line verdict + "details in the GitHub review; resolve everything, including CodeRabbit threads, in one pass".
  2. **Requirement context:** current scope, what changed vs the PR description/Discovery (date + source), what is out of scope.
  3. **Changes needed:** short numbered list grouped by area (blockers first, then follow-ups to include in the same pass).
  4. **CodeRabbit:** fix its comments except the ones skipped (name them briefly; the reasons are on the threads). One line asking CodeRabbit to use the requirement context on its next review.
  5. **Before PR Ready again:** PR description update, squash, config/deploy notes.

### Report add-on (after the review is posted)

````markdown
## Suggested Odoo "PR Needs Changes" note
Task → PR Needs Changes → paste into "Changes Needed" → Send to Ready.
This posts to chatter, moves the task to Ready, and comments on the PR as "FYI : @coderabbitai".

```text
…note…
```
````

Never submit the wizard yourself (Odoo write + stage move + PR comment) unless the user explicitly asks for that named action.

## Anti-patterns

- Reviewing the tip commit only
- Approving because the bot is green while claim↔code gaps remain
- Treating sibling-module drive-bys as “part of the feature” without calling them out
- Duplicating `AGENTS.md` into a long essay instead of gating findings
- Committing, pushing, merging, or `gh pr edit` unless the user explicitly asks
- Treating “drop X from the PR” / “return to PR Ready” as commit or push permission
- Implementing post-review fixes and shipping them in the same turn without `commit-comment`
- Checking out the PR branch onto the shared worktree when fetch/show would do
- Inventing UAT pass/fail
- **Holding the verdict or drafting comments because UAT/functional testing is missing** (prior stage)
- Writing a Test plan / post-merge smoke checklist as the review deliverable
- **Posting GitHub inline/review comments without explicit user approval of the draft pack**
- Posting every CodeRabbit nit as an inline comment
- Submitting the Needs Changes wizard yourself, prefixing the note with `FYI : @coderabbitai`, or pasting the full report / markdown tables into it

## Related skills

- `odooer-day-ops` / `contracts.md` — orchestrator handoff + shared contract fence
- `commit-comment` — commit plan after review-driven fixes (agent does not commit)
- `dev-story-workflow` — handoff story implementation loop (not PR verdict)
