---
name: odoo-prod-ticket-resolution
description: Investigates and resolves Odoo production helpdesk tickets from an ID or URL, including duplicates, stale reports, data corrections, configuration, and code defects. Uses MCP and the codebase, gates mutations by approval, tracks code through production verification, returns Mark as Solved values when closure-ready, and after the user closes an AI-suggested resolution provides Rate AI Resolution stars/tags/note. Use only when explicitly requested for production ticket investigation or resolution.
disable-model-invocation: true
---

# Odoo Production Ticket Resolution

Resolve production tickets through evidence, triage, approval, safe execution, independent verification, accurate closure, and AI resolution rating when the Rate AI Resolution wizard applies.

## Safety contract

- Treat production as read-only until the user explicitly approves a specific mutation plan.
- Never infer approval from a request to investigate, diagnose, preview, or explain.
- Prefer standard Odoo business methods over direct field writes, and ORM over SQL.
- Never remove records without proving they are stale and explaining accounting and audit effects.
- Do not mark **Verified by customer** based on technical or UI verification.
- Redact secrets and unnecessary personal or customer data.

## Workflow

### 1. Identify and read the ticket

Accept a ticket ID, `model=helpdesk.ticket&id=<id>`, or an Odoo URL. Confirm the model, record ID, production instance, and company.

Discover MCP schemas before calling tools. Read:

- Subject, description, stage, team, assignee, company, priority, type, tags, and timestamps
- Intake fields, reproduction steps, URL/model/action/menu metadata, and business impact
- Chatter, tracking values, activities, and attachments
- Escalations and every linked requirement, task, duplicate, parent/child ticket, sale order, payment, picking, or other business record
- Existing resolution and previous solve/reopen history

Use model metadata and relationship inspection instead of assuming custom field names. Read escalation records themselves even when a displayed escalation count is zero; routing logs and technical escalations may use different counters.

Build a short evidence timeline. Treat the ticket statement as historical evidence, not proof that production still has the same state.

As soon as the ticket id and subject are known, include a one-line **Chat title** suggestion in that same response so the user can rename the Cursor conversation manually. Agents cannot rename chats. Follow the Chat title rules under Response checkpoints.

### 2. Run the triage gate

Before deep diagnosis or proposing a correction:

- Search for earlier tickets with the same linked record, URL, reference, requester, or distinctive keywords.
- Check solved and customer-confirmed tickets for duplicates.
- Compare ticket creation time with affected records' `write_date` and chatter.
- Reproduce or recheck the symptom when safe.
- Classify the path as duplicate, already resolved/transient, guidance, configuration, data correction, code defect, access, or integration.

Follow [TRIAGE.md](TRIAGE.md). Stop early when the duplicate, guidance, or already-resolved path is proven.

### 3. Diagnose only as deeply as needed

For unresolved issues, follow the linked business record and compare expected versus actual records, counts, totals, states, relationships, healthy sibling records, tracking history, company scope, and stale artifacts.

Inspect the local code owning the fields, defaults, actions, buttons, computes, constraints, and business methods. Search every caller of the relevant method. Read `critical_overrides.md` before proposing an override when it exists.

For UI-default issues, inspect the window action context, user memberships, record sequences, team-specific configuration, onchange domains, and access profiles.

For code defects, separate business classification, routing, and downstream task behavior. Confirm disputed business rules with an accountable owner before encoding them. Inspect current production behavior and blast radius across shared models, then follow [CODE-DEFECT.md](CODE-DEFECT.md).

Explain:

1. What changed
2. Which automation did or did not run
3. Why the symptom followed
4. Which records remain inconsistent
5. The issue classification

Do not mutate data during diagnosis.

### 4. Choose the smallest safe resolution

Do not force a correction or shell script when retrying, user guidance, duplicate closure, or a prior manual correction fully resolves the issue.

When mutation is needed, present the exact current state, desired state, ordered steps, affected records, business and audit effects, preconditions, postconditions, rollback, and retained historical artifacts. Ask for explicit confirmation of that exact plan.

If a material business choice exists, ask rather than silently selecting a record, team, vehicle, account, stage, or configuration.

### 5. Provide execution guidance after approval

Provide only paths that actually exist:

- **UI:** menu or URL, record, controls, values, expected intermediate results, and final checks.
- **Odoo shell:** read-only preflight followed by an approval-matching, rollback-safe apply block.

Never invent a UI action or provide a data-correction script for a code deployment, duplicate, or guidance-only resolution. Follow [SHELL-SAFETY.md](SHELL-SAFETY.md) whenever shell mutation is appropriate.

### 6. Independently verify

After the user shares shell output or UI confirmation:

- Re-read production through MCP instead of trusting supplied output alone.
- Verify the original symptom plus source, generated, paired, and stale records as applicable.
- Verify counts, totals, states, links, reconciliation, company, and audit state.
- For deployed code, verify the production version and reproduce the original workflow; staging success is not production verification.
- Report any remaining discrepancy directly.

Do not perform adjacent cleanup without new approval.

### 7. Prepare closure

Inspect the installed Mark as Solved wizard, model, view, and templates because required fields and visibility may be customized.

Provide copy-ready outcome, category, summary, root cause, internal notes, customer verification, and duplicate pointer. Follow [CLOSURE.md](CLOSURE.md).

Do not wait for the user to ask for closure. As soon as verification proves the ticket closure-ready, include the complete copy-ready Mark as Solved values in the same response. If deployment or a required business step is pending, state that closure is premature and provide clearly labeled draft values only when useful.

Technical or UI confirmation is not customer confirmation. Check **Verified by customer** only when the requester actually confirmed.

Do not write closure fields or move the ticket unless explicitly requested.

### 8. Rate the AI resolution after the user closes

When the user confirms Mark as Solved and the **Rate AI Resolution** wizard opens (or they ask for the AI rate), provide copy-ready stars, tags, and note. Follow [AI-RATING.md](AI-RATING.md).

This step scores the **in-Odoo investigator suggestion** against the human-final resolution. It is the Salam AI HITL feedback loop: reviews pin `ai.agent.version` so prompt/config quality can be measured over time. It is not a grade of the Cursor dig.

- Compare AI **proposed** resolution (wizard diff or pre-confirm AI-filled fields) to the **final** Mark as Solved values.
- Choose 1–5 stars (5→ok, 3–4→needs_improvement, 1–2→failed), tags (Useful, Good Dig, Wrong Resolution, Hallucination, Incomplete), and a short note tied to the proposed→final gap.
- Do not wait for the user to ask once the wizard is in play; include the paste-ready block in that response.
- Tell the user to **Skip** only when Mark as Solved had no AI-suggested resolution.
- Do not submit the review via MCP/shell unless explicitly asked; the user clicks Submit or Skip.

## Response checkpoints

0. **Chat title:** one-line rename suggestion (first response after the ticket is identified)
1. **Investigation:** evidence, freshness, classification, and root cause
2. **Plan:** smallest safe resolution and risks, awaiting approval when mutation is needed
3. **Execution guidance:** available UI and shell paths
4. **Verification + closure:** fresh MCP confirmation followed immediately by copy-ready Mark as Solved values when closure-ready
5. **Pending deployment:** exact remaining gate and draft closure values if useful
6. **AI rating:** after the user Mark as Solved with an AI-suggested resolution (wizard open), copy-ready stars, tags, and note per [AI-RATING.md](AI-RATING.md)

### Chat title

Cursor chats cannot be renamed by the agent. Always suggest one paste-ready title early; the user renames manually.

Output exactly one line in this form:

```text
Chat title: <short distinctive title> (#<ticket_id>)
```

Rules:

- One line only; no alternatives, no explanation, no “please rename” prompt
- Include the ticket id in `(#…)`
- Prefer the symptom or subject, not the workflow stage (“In Progress”, “Routed”)
- Keep it short enough for the chat sidebar (about 6–12 words before the id)
- Redact secrets and unnecessary personal data; do not invent details not on the ticket
- Suggest once when the ticket is first identified; do not repeat on later checkpoints unless the user asks

Example:

```text
Chat title: AI intake_steps append (#415800)
```

See [EXAMPLES.md](EXAMPLES.md) for branch examples derived from real ticket patterns.
