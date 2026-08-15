# AI Resolution Rating

After the user confirms Mark as Solved and the **Rate AI Resolution** wizard opens (`ai.feedback.review.wizard` / view `salam_ai_feedback_ai_feedback_review_wizard_view_form`), provide copy-ready rating values. Do not skip this when an AI-suggested resolution was part of the close path.

## Purpose

AI ratings are the Support HITL feedback loop for Salam AI (`salam_ai_feedback`):

- Score how good the **investigator agent’s resolution suggestion** was versus what the human finally confirmed.
- Persist a subject-scoped review (`res_model` + `res_id`, usually `helpdesk.ticket`) with stars, tags, note, and proposed→final diff.
- Attribute that score to the **agent version** that produced the suggestion so prompt/config changes can be evaluated over time.
- Feed later curation (few-shot bank from reviews); v1 stores examples only — ratings do not auto-rewrite prompts.

Ratings are **not** a grade of the Cursor chat, the MCP dig, or the human’s final Mark as Solved quality. Rate the **in-Odoo AI resolution suggestion** only.

## When this step applies

Provide paste-ready wizard values when **any** of these are true:

1. The user says they closed / Mark as Solved and the Rate AI Resolution wizard is open.
2. Confirming Mark as Solved opened `action_open_review` because `odoo_support_resolution_ai_suggested` was set on the ticket.
3. The ticket had AI-prefilled resolution fields that the human edited or accepted.

Skip (or say “no AI rating — Skip”) only when Mark as Solved ran with **no** AI-suggested resolution (`was_ai_suggested` false / wizard never opens). Do not invent a rating for a purely human-written resolution.

Do not create `ai.feedback.review` via MCP or shell unless the user explicitly asks. The user submits the wizard (or Skip).

## How it ties to agent versioning

| Piece | Role |
|-------|------|
| `ai.agent` | Investigator agent that suggested resolution fields |
| `ai.agent.version` / `ai.topic.version` | Automatic snapshots when agent/topic config changes |
| `ai.feedback.review.agent_version_id` | Set at submit to `agent.current_version_id` when omitted |
| `proposed_json` / `final_json` | Adapter snapshots: AI proposal vs human final Mark as Solved |
| `response_log_ids` | Optional link to `ai.response.log` rows for that ticket dig |

A rating without a version pin is much less useful: you cannot tell which prompt/tools/topics produced a weak or strong suggestion. The product already pins the version on submit — the agent’s job is an honest score and note that explain the proposed→final gap.

## Wizard fields

### Rating (required)

Stars **1–5**. Status is derived automatically:

| Stars | Status | Use when |
|-------|--------|----------|
| **5** | OK | AI proposal was accepted with only trivial wording tweaks |
| **4** | Needs Improvement | Mostly right; small outcome/category/summary fixes |
| **3** | Needs Improvement | Directionally useful but wrong outcome, incomplete dig, or large rewrite |
| **2** | Failed | Materially wrong resolution; would have misled closure |
| **1** | Failed | Harmful or nonsensical suggestion |

### Tags (optional, multi)

Installed defaults (`ai.feedback.tag`):

| Tag | Code | Use when |
|-----|------|----------|
| Useful | `useful` | Classification, scope, or framing helped even if incomplete |
| Good Dig | `good_dig` | AI retrieved the right records/evidence for the resolution |
| Wrong Resolution | `wrong_resolution` | Outcome, category, or closure path was wrong |
| Hallucination | `hallucination` | Invented records, IDs, or facts not in production |
| Incomplete | `incomplete` | Missed the deliverable dig, key records, or required closure detail |

Combine tags when accurate (e.g. Useful + Incomplete). Do not use Hallucination for “incomplete but honest.” Prefer Wrong Resolution when outcome changed (e.g. Referred → Fixed).

### Additional Note

One short paragraph (2–4 sentences):

1. What the AI proposed (outcome / category / gist).
2. What the human confirmed (outcome / category / gist).
3. Why the stars and tags fit (cite the main proposed→final deltas).
4. Record refs only when they prove the gap (SO/ticket ids already in internal notes are fine).

Do not paste the full Mark as Solved block into the note. Do not rate Cursor/MCP work as if it were the Odoo agent.

## How to build the rating

1. Re-read the ticket resolution fields after close (outcome, category, summary, root cause, internal notes, verified).
2. Recover the AI proposal from the wizard **Review Resolution Changes** diff when visible; otherwise from pre-confirm evidence (`odoo_support_resolution_ai_suggested` snapshot, earlier ticket read, or chat history of AI-filled fields).
3. Diff proposed vs final on: outcome, category, summary, root cause, verified, duplicate, internal notes.
4. Choose stars from the table above; pick tags that match the gap; write the note from that diff.
5. Output copy-ready values for the open wizard. Do not submit for the user.

## Copy-ready format

```text
AI rating: <1–5> stars
Tags: <comma-separated tag names, or None>
Additional Note:
<2–4 sentence note tied to proposed → final>
```

## Examples

### Accepted with light edit → 5

AI Fixed/Data matched production; human only shortened the summary.

```text
AI rating: 5 stars
Tags: Useful, Good Dig
Additional Note:
AI proposed Fixed/Data with the correct stale pair cleanup narrative; human kept outcome/category and only tightened the summary. Diff is wording-only.
```

### Useful classification, incomplete deliverable → 3

AI Referred / custom-report framing; human Fixed after completing the audit (ticket #418411 pattern).

```text
AI rating: 3 stars
Tags: Useful, Incomplete, Wrong Resolution
Additional Note:
AI correctly classified a non-bug identification/audit (category Other) but proposed Referred instead of Fixed and did not list matching Digital Retail SO ↔ other-team quotation pairs. Human completed the dig and closed Fixed/Other with the overlap refs.
```

### Invented records → 1–2

```text
AI rating: 2 stars
Tags: Hallucination, Wrong Resolution
Additional Note:
AI cited sale order / partner ids that do not exist on production for this customer. Human discarded the suggestion and closed from MCP-verified records only.
```

## Automatic handoff

- After the user reports Mark as Solved (or shows the Rate AI Resolution wizard), provide the AI rating block in the **same** response — do not wait to be asked.
- If the wizard is open but there was no AI suggestion, tell the user to **Skip**.
- Do not reopen business diagnosis unless the rating work reveals an unresolved production discrepancy.
