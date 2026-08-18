---
name: odoo-prod-ticket-resolution
description: Investigates and resolves Odoo production helpdesk tickets from an ID or URL, including duplicates, stale reports, data corrections, configuration, and code defects. Uses MCP and the codebase, gates mutations by approval, tracks code through production verification, and automatically returns Mark as Solved values when closure-ready. Use only when explicitly requested for production ticket investigation or resolution.
disable-model-invocation: true
---

# Odoo Production Ticket Resolution

Resolve production tickets through evidence, triage, approval, safe execution, independent verification, and accurate closure.

## Safety contract

- Treat production as read-only until the user explicitly approves a specific mutation plan.
- Never infer approval from a request to investigate, diagnose, preview, or explain.
- Prefer standard Odoo business methods over direct field writes, and ORM over SQL.
- Never remove records without proving they are stale and explaining accounting and audit effects.
- Do not mark **Verified by customer** based on technical or UI verification.
- Redact secrets and unnecessary personal or customer data.

## Workflow

### 0. Suggest a title

After identifying the ticket, immediately suggest a short descriptive title (max 8 words) for this investigation session based on the ticket subject, affected model, and symptom. Present it at the top of the first response so the user can rename the chat.

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

## Response checkpoints

1. **Investigation:** evidence, freshness, classification, and root cause
2. **Plan:** smallest safe resolution and risks, awaiting approval when mutation is needed
3. **Execution guidance:** available UI and shell paths
4. **Verification + closure:** fresh MCP confirmation followed immediately by copy-ready Mark as Solved values when closure-ready
5. **Pending deployment:** exact remaining gate and draft closure values if useful

## AI resolution rating

At the end of every ticket resolution (after closure values), provide a short **AI Rating** block comparing the ticket's original AI-generated contribution (if any existed on the ticket, e.g. auto-classification, suggested reply, or AI notes) against the AI-suggested resolution produced during this session.

```text
AI Rating
─────────
Original AI contribution : <what the ticket's AI fields contained, or "None">
AI suggested resolution  : <one-line summary of this session's resolution>
Accuracy delta           : <Better / Same / Worse — did the original AI help, miss, or mislead?>
Notes                    : <brief explanation of the gap, e.g. "Original auto-classification was correct but resolution suggestion missed the stale record">
```

If the ticket had no prior AI contribution, state "None" and skip the accuracy delta.

See [EXAMPLES.md](EXAMPLES.md) for branch examples derived from real ticket patterns.
