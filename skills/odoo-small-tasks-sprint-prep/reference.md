# Sprint-prep reference

Lookup tags and stages by name each run. IDs below are live fallbacks only.

## Tags (`project.tags`)

| Name | Fallback id |
|---|---|
| ready | 73 |
| Need Clarification | 74 |
| next sprint | 77 |
| Need Call | 59 |
| Need Assistance | 1 |

```python
# credit seats
[["is_odoo_small_task", "=", True], ["dev_stage_key", "=", "backlog"], ["tag_ids", "in", [73]]]
# already next sprint
[["is_odoo_small_task", "=", True], ["dev_stage_key", "=", "backlog"], ["tag_ids", "in", [77]]]
# Need Call (out)
[["is_odoo_small_task", "=", True], ["dev_stage_key", "=", "backlog"], ["tag_ids", "in", [59]]]
```

Tag writes: `{"tag_ids": [[4, 73], [4, 77]]}`. To strip a bad `ready`: `[[3, 73]]` then `[[4, 74]]`.

## Task fields to read

`id`, `name`, `create_date`, `user_ids`, `tag_ids`, `helpdesk_ticket_id`, `description`, `story_ids`, `req_discovery_normalization`, `req_discovery_functional_scope`, `req_discovery_readiness_check`, `req_discovery_effort_signal`, `req_discovery_business_risks`

Ticket: `id`, `name`, `description`, `ticket_type_id`, `requester_employee_id`, `requester_department_id`, `priority`

`requester_department_id` is related, not stored. For demand families, query tickets from `helpdesk_ticket_id` on the task set — do not start from `small_dev_task_id`.

## Department families

Same map as the weekly small-tasks skill. Never label IT as IT — use **Odoo Support**.

| Family | Match |
|---|---|
| Retail | showrooms, Credit, BDF |
| Finance | AP/AR, Tax & Bank, CCO |
| Odoo Support | IT / tickets filed by the Odoo Support team |
| Call Center, Procurement, Service Center, Marketing, HR & Admin, Logistics, Social Media, Warehouse, Management, Properties, Inventory | name contains that area |

**Cap 4** (including credited seats): Call Center, Finance, Logistics, Retail.

## Developer user ids (fallback)

Saleh 248, Ahmed 274, Aqeel 549, Kadhem 753, Kareem 769, Ameen 774, Dahab 775.

## MCP writes

`ODOO_MCP_ENABLE_WRITES` must be on. Instance: `default`.

1. `validate_write` on `project.task` (`operation=write`) with Discovery HTML + `tag_ids`.
2. Immediate `execute_approved_write` with that approval token (`confirm=true`).
3. `validate_write` on `project.task.story` (`operation=create`, `use_live_metadata=true`) with `values_list`.
4. Immediate `execute_approved_write`.
5. `read_record` the task: `tag_ids` includes 73 and 77, `user_ids` is `[]`, `story_ids` populated.

Do not call `preview_write` as a substitute. If the token expires, validate again.

Discovery HTML example:

```html
<p>One-paragraph rewrite of the ticket.</p>
<p><strong>In scope</strong></p>
<ul><li>…</li></ul>
<p><strong>Out of scope</strong></p>
<ul><li>…</li></ul>
```

Story create example:

```json
{
  "epic_task_id": 326854,
  "sequence": 10,
  "role": "Repair cashier",
  "intent": "have the draft become Reconciled after Create Payment",
  "value": "the invoice is paid and the draft is no longer Registered",
  "technical_notes": "module.method; demo record if known",
  "complexity": "s",
  "points": "3"
}
```

`points` and `complexity` are selections — send strings. Do not create an Unplanned story.

## Remaining-count line

After each write (and when asked):

`Written N · Parked (Need Clarification / cancelled) N · Remaining N` plus the remaining ids.

## Chat links

Task: `https://salamgas.odoo.com/web#id={id}&model=project.task&view_type=form`
Ticket: `https://salamgas.odoo.com/web#id={id}&model=helpdesk.ticket&view_type=form`
