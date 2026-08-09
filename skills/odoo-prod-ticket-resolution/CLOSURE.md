# Ticket Closure

Inspect the installed solve wizard, ticket model, view, mail template, and portal template before relying on this guide.

## Visibility

- **Resolution Summary:** customer-safe text; commonly displayed in confirmation email and portal.
- **Resolution Root Cause:** factual internal diagnosis unless the installed templates expose it.
- **Resolution Internal Notes:** internal audit detail; do not assume it is posted to chatter.
- **Verified by customer:** means the requester actually confirmed by phone, chat, email, portal, or in person.

Technical checks, MCP verification, and support-agent UI confirmation do not count as customer confirmation.

## Outcome and category guide

Use installed selection values. Typical mappings:

- Proven duplicate → **Duplicate**, set **Duplicate Of**, category usually empty
- Targeted record repair → **Fixed / Data**
- Shared setting or ordering corrected → **Fixed / Configuration**
- Existing UI path explained → **Workaround** or **Fixed / User Guidance**, based on whether the business outcome is complete
- Deployed code correction → **Fixed / Bug**
- External provider issue → suitable non-fixed outcome or **External**
- Unable to reproduce after freshness checks → **Cannot Reproduce**

Do not label a historical data conflict as a code bug merely because the ticket type says Bug.

## Copy-ready format

```text
Outcome: <installed selection>
Category: <installed category or empty>
Resolution Summary: <one customer-safe sentence describing the result>
Resolution Root Cause: <one factual sentence explaining why it happened>
Resolution Internal Notes: <one concise audit sentence with key record references>
Verified by customer: <Checked only after requester confirmation; otherwise Unchecked>
Duplicate Of: <original ticket or Empty>
```

## Writing rules

- Summary: state what was restored, completed, corrected, or explained. Avoid internal IDs unless useful to the requester.
- Root cause: state the proven mechanism; avoid speculation.
- Internal notes: record important old/new records, generated references, deleted or retained artifacts, configuration values, and verification method.
- Duplicate: avoid copying the original resolution into the duplicate when the wizard stores a pointer automatically.
- Already resolved: say that the retry succeeded and list generated records internally.

## Final check

Before presenting closure values:

1. Re-read the ticket and affected records through MCP.
2. Confirm the chosen outcome matches the actual resolution path.
3. Confirm category-dependent required fields.
4. Confirm whether customer confirmation is pending.
5. Keep each field short enough to paste directly into the wizard.

## Automatic handoff

Closure is part of verification, not a separate user request.

- When fresh MCP evidence proves the resolution complete, append the full copy-ready closure block to the verification response automatically.
- Do not ask whether the user wants closure values.
- If the requester still has a normal business action to perform, distinguish it from unresolved support work. Close only when the reported support issue itself is resolved and accurately mention the pending user action internally.
- If production deployment, migration, retry, or required verification is pending, keep the ticket open.

For code fixes:

- Local implementation, commit, push, staging deployment, or a scheduled production deployment is not **Fixed** in production.
- Use **Fixed / Bug** only after production deployment and verification of the original workflow.
- Before that point, provide closure text only as a clearly labeled draft for use after verification.
