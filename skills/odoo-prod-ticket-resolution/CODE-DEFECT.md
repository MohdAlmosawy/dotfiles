# Code Defect Resolution

Use this branch when evidence points to custom or core code rather than a one-record correction.

## Diagnose

1. Capture the exact traceback, failing model/method, input, user, company, and timestamp.
2. Recheck current production and search earlier tickets with the same exception or workflow.
3. Read the owning method, every override and caller, view domains/onchanges, and related configuration.
4. Trace the whole workflow across source and downstream records. Distinguish:
   - Business classification
   - Validation and configuration
   - Automation and generated records
   - Routing, assignment, and later operational handling
5. Prove the smallest failing condition and the unaffected paths.

Do not treat configuration as business truth when the reported rule is disputed. Confirm material policy with the responsible supervisor or owner before encoding it.

An older ticket closed as Cannot Reproduce is not a reliable duplicate target when new evidence proves the defect remained unresolved. Keep the ticket containing the best reproducible evidence as the active defect unless the team deliberately chooses another canonical ticket.

## Design the fix

- Fix the narrowest authoritative seam.
- Scope changes on shared models so unrelated workflows remain unchanged.
- Prefer configuration-driven invariants over hardcoded record IDs or broad assumptions.
- Preserve valid exceptions; for example, classification and corrective/preventive routing may be independent.
- Do not use production shell data writes to imitate a deployment.
- Quantify affected users, teams, models, and existing records.
- Ask for a business decision when multiple classifications or policies are valid.

## Validate and deploy

Track these states separately:

1. **Implemented locally** — not resolved
2. **Validated locally/staging** — not resolved in production
3. **Deployed to production** — verification still required
4. **Verified in production** — eligible for Fixed / Bug closure

Use focused automated tests when accepted and practical. Always compile/lint the edited files and validate by affected module upgrade plus the original workflow. If tests are declined or unavailable, state the remaining coverage gap instead of claiming equivalent assurance.

After deployment:

- Reproduce the original action in production.
- Verify created/updated records through MCP.
- Test at least one normal path and every important excluded or special path.
- Confirm downstream records and routing remain correct.
- Do not mark Fixed merely because code was pushed, merged, staged, or scheduled for deployment.

## Closure

After fresh production verification, immediately return Mark as Solved values in the same response:

- Outcome: **Fixed**
- Category: **Bug**
- Customer-safe summary of restored behavior
- Factual root cause
- Internal note naming the module, production verification record/workflow, and retained limitations
- Verified by customer only with actual requester confirmation

When production deployment is pending, keep the ticket open. Draft closure text may be supplied, but label it **use only after production verification**.
