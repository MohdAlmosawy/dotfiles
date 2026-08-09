# Production Odoo Shell Safety

Use shell mutation only after the user approves the exact plan and when the UI cannot safely perform it.

## Before writing

- Recommend a current database backup.
- Inspect every called custom method for explicit commits, cron handoffs, queued jobs, notifications, and external API calls.
- If a called method commits internally, state that full rollback is not guaranteed.
- Prefer a standard business method over reproducing its side effects manually.
- Avoid `sudo()` unless required and justified.
- Avoid raw SQL unless no safe ORM route exists and the user separately approves it.

## Read-only preflight

Provide a separate preflight block that:

- Browses exact IDs and asserts human-readable names or references.
- Checks company, state, relationships, totals, counts, and reconciliation.
- Prints `write_date` and `write_uid`.
- Checks that the intended correction does not already exist.
- Prints every record that would be created, changed, cancelled, unlinked, or retained.
- Performs no writes and no commit.

## Apply block requirements

- Repeat all preconditions; never rely on an earlier shell session.
- Assert the expected `write_date` snapshot when practical to detect concurrent changes.
- Use ORM and relational commands.
- Keep writes in one transaction where supported.
- Re-read records after mutation and assert every postcondition.
- Roll back on any exception.
- Commit only after all postconditions pass.
- Print IDs, names, states, totals, counts, links, and reconciliation results.

```python
try:
    # Browse exact records.
    # Assert identities, company, state, write_date, and idempotency.
    # Perform only the approved ORM/business-method changes.
    # Re-read and assert every postcondition.
except Exception:
    env.cr.rollback()
    print("ROLLED BACK: correction failed")
    raise
else:
    env.cr.commit()
    print("COMMITTED: correction completed")
```

## Destructive operations

Before `unlink()`:

1. Prove each record is stale or invalid.
2. Check posted, reconciled, delivered, invoiced, or externally synchronized state.
3. Explain why cancellation, archival, or retaining audit history is insufficient.
4. List exact IDs in preflight.
5. Verify absence after commit.

Cancelled historical records may be intentionally retained even when counters still include them. Report that limitation instead of silently deleting audit history.

## After user execution

Do not trust terminal prints alone. Re-read production through MCP and verify:

- Source record state
- Generated and paired records
- Counts and totals
- Statement or reconciliation state
- Removed or retained stale artifacts
- Original user-visible symptom
