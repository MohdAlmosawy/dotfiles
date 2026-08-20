# AI Resolution Rating

After Mark as Solved confirm, when the ticket had an AI-suggested resolution, Odoo opens **Rate AI Resolution** (`ai.feedback.review.wizard`). Provide copy-ready stars, tags, and note for that wizard. Do not invent a separate chat-only rating.

## Purpose

Support HITL feedback for Salam AI (`salam_ai_feedback`):

- Score the **Odoo Support AI Investigator** resolution suggestion versus what the human confirmed.
- Persist `ai.feedback.review` on the ticket (`res_model='helpdesk.ticket'`, `res_id=<id>`) with `rating`, `tag_ids`, `note`, and `proposed_json` → `final_json` diff.
- Pin `agent_version_id` on submit for later prompt/config evaluation and few-shot curation.

Rate the **in-Odoo AI resolution suggestion** only — not the Cursor chat, MCP dig, or human Mark as Solved quality.

## When this step applies

Provide paste-ready wizard values when any of these are true:

1. Mark as Solved opened **Rate AI Resolution** because `odoo_support_resolution_ai_suggested` was set at confirm.
2. The user reports the rating wizard is open.
3. The ticket had AI-prefilled resolution fields that the human edited or accepted.

Skip (or say **Skip**) when Mark as Solved ran with no AI-suggested resolution — the wizard does not open. Do not invent a rating for a purely human-written resolution.

Do not create `ai.feedback.review` via MCP or shell unless the user explicitly asks. The human submits (or Skips) the wizard.

## Read current rating via MCP

Before suggesting values, always search production:

```text
model: ai.feedback.review
domain: [('res_model', '=', 'helpdesk.ticket'), ('res_id', '=', <ticket_id>)]
order: review_date desc
fields: rating, status, note, tag_ids, proposed_json, final_json, diff_summary, agent_id, review_date, reviewer_id
```

Also load active tags:

```text
model: ai.feedback.tag
domain: [('active', '=', True)]
order: sequence asc
fields: id, name, code
```

If a review already exists for this ticket, summarize it and do not propose a duplicate unless the user asks to revise.

## Wizard fields

### Rating (required, priority widget 1–5)

Status is derived automatically (`ai.feedback.review.status_from_rating`):

| Stars | Status | Use when |
|-------|--------|----------|
| **5** | OK | AI proposal accepted with only trivial wording tweaks |
| **4** | Needs Improvement | Mostly right; small outcome/category/summary fixes |
| **3** | Needs Improvement | Useful dig but material gaps, wrong path, or large rewrite |
| **2** | Failed | Materially wrong resolution; would have misled closure |
| **1** | Failed | Harmful, hallucinated, or nonsensical suggestion |

### Tags (optional, multi — resolve names via MCP)

Typical helpdesk tags (`ai.feedback.tag`):

| Tag | Code | Use when |
|-----|------|----------|
| Useful | `useful` | Classification, scope, or framing helped |
| Good Dig | `good_dig` | Right records/evidence identified |
| Wrong Resolution | `wrong_resolution` | Outcome, category, or closure path was wrong |
| Hallucination | `hallucination` | Invented records, IDs, or facts |
| Incomplete | `incomplete` | Missed blockers, prerequisites, or sibling records |

Combine when accurate (e.g. Good Dig + Incomplete). Prefer Wrong Resolution when outcome changed (e.g. Fixed → Referred). Do not use Hallucination for an honest incomplete dig.

### Additional Note

2–4 sentences paste-ready for the wizard **Additional Note** field:

1. What the AI proposed (outcome / category / gist).
2. What the human confirmed.
3. Why the stars and tags fit (cite main proposed→final deltas).
4. Record refs only when they prove the gap.

Do not paste the full Mark as Solved block. Do not rate Cursor/MCP work as if it were the Odoo agent.

Diff keys used by the product: `outcome`, `category`, `summary`, `root_cause`, `verified`, `duplicate`, `internal_notes`.

## How to build the rating

1. Re-read ticket resolution fields after close (or the intended human final values).
2. Recover the AI proposal from wizard **Review Resolution Changes**, pre-confirm ticket snapshot, or earlier MCP read of AI-filled resolution fields.
3. Diff proposed vs final on the keys above.
4. Choose stars, tags, and note from that diff.
5. Output copy-ready values. Do not submit for the user.

## Copy-ready format

```text
Rate AI Resolution
──────────────────
Rating: <1–5> stars
Tags: <comma-separated tag names from ai.feedback.tag, or Empty>
Note: <2–4 sentence note tied to proposed → final>
```

## Examples (from production patterns)

### 5 — accepted, light edit

```text
Rate AI Resolution
──────────────────
Rating: 5 stars
Tags: Useful, Good Dig
Note: AI proposed Fixed/Data with the correct stale-pair cleanup narrative; human kept outcome/category and only tightened the summary. Diff is wording-only.
```

### 4 — mostly right, minor path edit

```text
Rate AI Resolution
──────────────────
Rating: 4 stars
Tags: Useful
Note: Dig and framing were correct; human only adjusted outcome/category labels. No record-level mistakes.
```

### 3 — good dig, incomplete / wrong path

```text
Rate AI Resolution
──────────────────
Rating: 3 stars
Tags: Good Dig, Incomplete
Note: AI correctly identified the key records and classified access/config (not a bug), but proposed Fixed without the HR job-position prerequisite. Human closed Referred with the correct prerequisite chain.
```

### 2 — wrong resolution / hallucination

```text
Rate AI Resolution
──────────────────
Rating: 2 stars
Tags: Hallucination, Wrong Resolution
Note: AI cited sale order / partner ids that do not exist on production for this customer. Human discarded the suggestion and closed from MCP-verified records only.
```

## Automatic handoff

- Include the rating block in the **same** response as Mark as Solved values when the ticket had AI-suggested resolution.
- After the user reports the wizard is open, provide values immediately — do not wait to be asked.
- If the wizard is open but there was no AI suggestion, tell the user to **Skip**.
- Do not reopen business diagnosis unless the rating work reveals an unresolved production discrepancy.
