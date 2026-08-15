# Resolution Branch Examples

These examples illustrate decisions, not fixed record names or commands.

Every branch still starts with a one-line chat title suggestion after the ticket is identified, for example:

```text
Chat title: AI intake_steps append (#415800)
```

## Missing generated records after manual reassignment

Evidence:

- A source record was moved to a new parent.
- Its generated pair and statement lines still reference the old parent.
- A processed flag prevents standard regeneration.

Path:

1. Prove the old generated records and lines are stale.
2. Present exact cleanup and regeneration effects.
3. Obtain approval.
4. Use the standard business method in a rollback-safe shell transaction.
5. Verify generated pair, counts, and reconciliation through MCP.
6. Close as **Fixed / Data**.

## Report changed after ticket creation

Evidence:

- Ticket reports two records sharing a resource.
- One record's `write_date` is later than ticket creation.
- Current records no longer have the reported conflict.

Path:

1. Separate historical facts from current facts.
2. Ask the user to retry the safe UI action.
3. If it succeeds, verify generated records through MCP.
4. Do not provide a correction script.
5. Close according to the proven current resolution and include the closure values with the verification response.

## Duplicate request

Evidence:

- Two tickets reference the same model and record ID.
- Their requested business action is the same.
- The older ticket is solved and customer-confirmed.

Path:

1. Stop underlying business investigation.
2. Use **Duplicate** and point to the older ticket.
3. Leave category and manually written summary empty when the wizard generates the pointer.

## Generic action defaults the wrong team

Evidence:

- The generic window action has no `default_team_id`.
- The user belongs to multiple teams.
- Team ordering selects a newly created team first.
- The selected team restricts available ticket types through onchange.

Path:

1. Verify user memberships, team sequences, action context, and ticket-type restrictions.
2. Prefer an existing team-specific UI action when guidance satisfies the request.
3. If changing shared sequence, quantify affected users and explain list-order impact.
4. Obtain approval, change the setting, verify through MCP, then have the user test both generic and team-specific creation.
5. Close as **Fixed / Configuration** when the shared setting was intentionally corrected.

## Code-path inconsistency

Evidence:

- One method explicitly exempts a special record type from an invariant.
- A later validator enforces the invariant without that exemption.

Path:

1. Determine whether current data still triggers the defect.
2. Avoid a shell workaround that masks the code issue.
3. Propose a scoped code fix and tests for ordinary, special, and invalid records.
4. Deploy through the normal module upgrade process.
5. Verify the original workflow in production.
6. Immediately provide **Fixed / Bug** closure values after production verification.

## Empty related record crashes a constraint

Evidence:

- Adding a section or note creates a line without a product.
- A custom constraint calls a singleton product method without checking that a product exists.
- The transaction rolls back with an Expected singleton traceback.

Path:

1. Search every caller of the singleton method.
2. Add product guards only where empty display lines are valid.
3. Preserve serial or lot validation for real product lines.
4. Deploy and add both a section and note in production.
5. Re-read the saved lines through MCP.
6. Return verification and **Fixed / Bug** closure values together.

## Classification differs from downstream routing

Evidence:

- Ticket type controls the business label.
- Issue type controls corrective/preventive skill.
- A later task and team inherit or route from those fields independently.
- Production configuration appears to reject a combination, but the business rule is initially disputed.

Path:

1. Inspect ticket type mappings, issue skill, task related fields, and team-routing code.
2. Check valid exceptions and current production usage.
3. Confirm the business rule with the responsible owner before coding.
4. Enforce the configured type/issue invariant at the source ticket while preserving downstream routing.
5. Keep existing records unchanged when the approved scope is code-only.
6. Treat staging or a scheduled deployment as pending; close **Fixed / Bug** only after production verification.

## AI suggested Referred; human completed the audit as Fixed

Evidence:

- Ticket asks for a one-off identification/report across sales orders and quotations.
- AI prefilled resolution as **Referred** / custom report, category Other.
- Human (with MCP dig) delivered the matching records and closed **Fixed** / Other.
- Rate AI Resolution wizard opens after Mark as Solved.

Path:

1. Deliver the identification list; close Fixed / Other with copy-ready Mark as Solved values.
2. After the user confirms Mark as Solved, rate the **Odoo AI suggestion**, not the Cursor dig.
3. Stars **3**, tags **Useful**, **Incomplete**, **Wrong Resolution**.
4. Note: AI classified non-bug audit correctly but wrong outcome and missing deliverable pairs.
5. User submits the wizard; review pins `ai.agent.version` automatically.

See [AI-RATING.md](AI-RATING.md).
