---
name: commit-comment
description: >-
  Group related changes into separate commits and output exact one-line git
  commands for the user to run. Use when the user asks to commit, split commits,
  group files, wants a commit comment, or mentions commit-comment.
disable-model-invocation: true
---

# Commit Comment

## Role

The agent **does not run** `git commit`. It:

1. Inspects `git status` and `git diff`
2. Splits changes into **related commits** (one concern per commit)
3. Outputs **exact commands** for the user to paste and run

## Commit message format

**One line only.** No body. No trailers.

```
[TAG] module_name: short imperative description
```

| Part | Rule |
|------|------|
| `TAG` | `[ADD]` new feature/data · `[IMP]` enhancement · `[FIX]` bugfix · `[REF]` refactor · `[REM]` removal · `[DOC]` docs |
| `module_name` | Top-level Odoo addon folder, e.g. `salam_odoo_support` |
| Description | Lowercase start after colon; complete sentence fragment; focus on **why/what**, not file list |

### Forbidden

- `Co-authored-by: Cursor` or any Cursor co-author trailer
- Multi-paragraph commit bodies
- `git commit` without `-m` (opens editor)
- Mixing unrelated modules or concerns in one commit
- Drive-by changes bundled into a feature commit

## Grouping rules (Odoo monorepo)

One top-level folder = one module. Group by **workflow slice**, not by file type.

Typical split order (dependency-aware):

1. **Base module first** — e.g. `salam_odoo_support` portal hooks others extend
2. **Downstream module next** — e.g. `salam_odoo_requirement`, then `salam_odoo_development`
3. **Within a module**, separate when concerns differ:
   - Portal UX / templates / SCSS
   - Model / controller business logic
   - Handoff or workflow engine changes
   - Demo / test data last

If a change spans modules, put each module's files in its own commit unless they are inseparable (same atomic feature).

## Workflow

```
1. git status --short
2. git diff          (and git diff --cached if needed)
3. git log -5 --oneline   (match existing style)
4. Propose commit groups with file lists
5. Output commands below — one block per commit, in run order
6. Wait for user to run each commit before proposing the next batch if they work incrementally
```

## Command template

Per commit, output exactly:

```bash
git add path/to/file1 path/to/file2 ...

git commit -m "[TAG] module_name: description"
```

Optional verification after each commit:

```bash
git status --short
```

Do **not** use HEREDOC unless the user explicitly prefers it. Default to a single quoted `-m` string.

## Examples (from this repo)

```bash
git add salam_odoo_support/controllers/helpdesk_portal.py salam_odoo_support/models/helpdesk_ticket.py salam_odoo_support/models/helpdesk_ticket_portal_journey.py salam_odoo_support/static/src/scss/portal_journey.scss salam_odoo_support/views/portal_help_templates.xml salam_odoo_support/views/portal_journey_templates.xml

git commit -m "[IMP] salam_odoo_support: improve portal journey UX and department access"
```

```bash
git add salam_odoo_requirement/controllers/helpdesk_portal_analysis.py salam_odoo_requirement/controllers/portal_communication.py salam_odoo_requirement/models/helpdesk_ticket.py salam_odoo_requirement/models/helpdesk_ticket_portal_journey.py salam_odoo_requirement/models/project_task_analysis.py salam_odoo_requirement/models/project_task_form_isolation.py salam_odoo_requirement/report/requirement_analysis_report.xml salam_odoo_requirement/static/src/scss/portal_requirement_journey.scss salam_odoo_requirement/views/portal_requirement_journey_templates.xml

git commit -m "[IMP] salam_odoo_requirement: rework portal analysis confirmation without PDF"
```

```bash
git add salam_odoo_development/__manifest__.py salam_odoo_development/models/helpdesk_ticket.py salam_odoo_development/static/

git commit -m "[IMP] salam_odoo_development: add portal journey phases for dev execution"
```

```bash
git add salam_odoo_development/models/project_task_handoff.py salam_odoo_development/models/project_task_capacity_gantt.py salam_odoo_development/views/project_task_views.xml

git commit -m "[IMP] salam_odoo_development: improve confirm-to-dev handoff and capacity gantt"
```

```bash
git add salam_odoo_development/demo/helpdesk_ticket_hub_demo.xml

git commit -m "[ADD] salam_odoo_development: add portal demo tickets for in_review and UAT phases"
```

## Response shape

When the user asks to commit:

```markdown
## Commit plan (N commits)

### 1. [IMP] salam_odoo_support: …
**Files:** `path/a`, `path/b`

\`\`\`bash
git add …
git commit -m "[IMP] salam_odoo_support: …"
\`\`\`

### 2. …
…
```

If only one commit remains, still use the same structure.

## Incremental mode

When the user says "next one" or pastes `git status` after a commit:

- Acknowledge the last commit
- Propose **only the next** commit in the plan
- Do not re-list already-committed groups
