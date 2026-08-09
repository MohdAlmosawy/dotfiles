# Ticket Triage

Run this gate immediately after reading the complete ticket.

## Evidence freshness

1. Record ticket `create_date` and reported record identifiers.
2. Re-read every affected record and note `write_date`, writer, state, links, and counts.
3. Read relevant chatter and tracking around the ticket timestamp.
4. If production changed afterward, describe the historical report and current state separately.
5. Reproduce or retry only when the action is non-destructive and the user can perform it safely.

Do not propose a correction for a state that no longer exists.

## Duplicate detection

Search existing tickets using:

- Exact linked model and record ID
- Intake URL and reference
- Business document name or number
- Requester plus distinctive keywords
- Duplicate pointers and related tickets

Prioritize older solved or customer-confirmed tickets. Read their resolution and chatter. Classify as duplicate only when both tickets concern the same business request or underlying issue, not merely the same customer or model.

Do not automatically close a reproducible defect as a duplicate of an older ticket that was closed without a fix, such as Cannot Reproduce. Decide which ticket should remain the canonical active defect based on evidence and team intent.

For a proven duplicate:

- Make no business-data correction.
- Use outcome **Duplicate**.
- Set **Duplicate Of** to the original ticket.
- Let the wizard generate its duplicate pointer summary when supported.

## Classification branches

### Already resolved or transient

Current data is valid and a safe retry succeeds. Verify generated records and stop; no shell script is needed.

### User guidance

The system behaves as configured and an existing UI path satisfies the request. Give exact navigation and verify it with the user.

### Configuration

Inspect action context, user membership, sequence/order, company, team settings, ticket types, tags, onchange domains, and access profiles. Quantify who a shared configuration change affects.

### Data correction

Identify exact inconsistent records, intended relationships, stale artifacts, accounting impact, and the standard business method that restores consistency.

### Code defect

Show the failing condition, owning code, callers, shared-model scope, downstream workflow, and unaffected paths. Separate business classification from routing and confirm disputed policy before coding. Do not disguise a deployment as a shell data correction. Follow [CODE-DEFECT.md](CODE-DEFECT.md).

### Access

Distinguish ACL, record rule, company scope, group membership, and missing functional configuration. Do not use `sudo()` as the diagnosis.

### Integration

Correlate Odoo state with integration logs, external identifiers, retries, idempotency keys, and timestamps. Avoid replaying requests until duplicate side effects are excluded.

## Decision rule

Choose the smallest resolution that restores the intended business outcome:

1. Duplicate closure
2. Safe retry
3. User guidance
4. Configuration correction
5. Targeted data correction
6. Tested code change

Escalate to a business choice whenever multiple records, teams, vehicles, accounts, or workflows could validly be selected.
