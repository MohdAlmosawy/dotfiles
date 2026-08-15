---
name: odoo-support-kb-articles
description: >-
  Rewrites and grounds Odoo Support Knowledge articles from helpdesk tickets
  (one or many URLs/IDs). Verifies stage voice, code, and resolution; updates
  article bodies via MCP; inserts inline Image capture notes; returns a final
  batch summary for the user to finalize and add screenshots. Use when the user
  pastes knowledge.article or helpdesk.ticket links for Support/User Article
  work, or asks to process KB articles in batch.
disable-model-invocation: true
---

# Odoo Support KB Articles

Process one or many Knowledge articles linked to Odoo Support helpdesk tickets. Investigate, rewrite, save, then hand the user a final pack so they can review and paste screenshots.

Instance default: `salamgas.odoo.com` via MCP server `user-odoo`. Discover tool schemas before calling.

## Input

Accept any mix of:

- Knowledge article URL (`model=knowledge.article&id=<id>`, often `active_id=<ticket_id>`)
- Helpdesk ticket URL (`model=helpdesk.ticket&id=<id>`)
- Bare article IDs, ticket IDs, or a list/batch of the above

Resolve each item to `(ticket_id, article_id)`:

1. If article URL/ID → read article; find linked ticket via `active_id`, body/ticket refs, or `helpdesk.ticket` with `knowledge_article_ids` containing the article.
2. If ticket URL/ID → read `stage_id`, intake, chatter; load `knowledge_article_ids`.
3. If ticket has no article → create under parent **Odoo Support Knowledge Base** (`knowledge.article` id `498`), `internal_permission=write`, then `knowledge_article_ids = [(4, new_id)]` on the ticket.

Process items **sequentially**. Do not stop the batch on one failure; record the miss and continue.

## Per-article workflow

### 1. Stage voice (mandatory first)

Read ticket `stage_id` before rewriting.

| Stage | Audience | Voice |
|-------|----------|--------|
| **User Article** | Business users | Menus, buttons, plain language. No modules, fields, XML IDs, code, ACL groups. |
| **Support Article** | Internal support | Modules, fields, methods, XML IDs, ACLs, shell OK. Playbook tone. |

If stage is neither, ask once; do not guess.

### 2. Gather truth (this order)

1. **Code / live DB** — owning module, exact UserError/domain/ACL, real menus, sample records that still exist.
2. **Ticket resolution** — solve note, outcome, category, customer confirmation, internal notes.
3. **Old article** — keep only what still matches 1–2.

Do not invent root causes. If resolution is thin, say so and ground what you can verify.

### 3. Rewrite rules

- Moderate length: clearer than ultra-terse; no source-citation noise (`[Source:…]`, `resolution_root_cause`).
- Structure usually: Summary → Root cause → Fix playbook (numbered) → Validate → Escalate if.
- Support: name modules/methods/fields when useful.
- User: instructional only; hide technical identifiers.
- Prefer focus: replace wrong content; do not drive-by unrelated KB edits.
- **Do not overwrite** bodies that already contain user-uploaded screenshots/`<img src=...>` unless the user asks to replace them — then keep or re-place image blocks intentionally.
- Never bump module versions. Never commit unless asked.

### 4. Images (inline, caption style)

Place each capture **under the playbook step it illustrates**, not in a dump-only section at the end.

Use this label form (verbatim style):

```html
<p><em>Image: short explanation of what the screenshot should show.</em><br>
Menu: Exact - Menu - Path<br>
Record: Display name (model id)<br>
URL: https://salamgas.odoo.com/web#id=…&amp;cids=1&amp;model=…&amp;view_type=form</p>
```

Rules:

- Say **`Image:`** then explain the picture. Do **not** write `Image placeholder:`.
- Prefer real surviving records (post-fix examples OK if originals are gone; note that in the caption).
- Conditional UI: say which record state makes the control visible.
- Escape `&` as `&amp;` in HTML bodies.

### 5. Save via MCP

1. `GetMcpTools` for `validate_write` / `execute_approved_write` as needed.
2. `validate_write` on `knowledge.article` (`write` or `create`).
3. `execute_approved_write` with `confirm: true` and the returned approval object.
4. Re-read article to verify body/name.
5. If create → link ticket `knowledge_article_ids`.

Write tips:

- Keep payloads compact enough for MCP execute (large HTML can fail parse).
- Retry once with a slightly smaller body if execute fails; do not silently skip save.
- One article per write approval.

### 6. Chat reply per item (short)

While batching, keep mid-batch status brief. Full detail goes in the **final batch report**.

## Final batch report (required)

After all items, give one report the user can use to finalize and add screenshots.

```markdown
## KB batch complete

| # | Ticket | Article | Stage | Status | Notes |
|---|--------|---------|-------|--------|-------|
| 1 | 407235 | [567](url) | Support Article | Updated | … |

### Article 567 — Multiple tripsheets…
- **Verdict:** what was wrong / what you fixed
- **Grounding:** code path + resolution fact
- **Article:** <url>
- **Screenshots to add** (in article order):
  1. Caption — Menu — [open record](url)
  2. …

### Article …
…
```

Also list:

- **Created** articles (new ids) vs **updated**
- **Blocked / skipped** with reason (missing ticket, ACL, execute failed, existing images not touched)
- **Open questions** only if they block accuracy

Do not paste the full HTML body in chat unless the user asks.

## Quick checklist

Copy and track for the batch:

```
KB Progress:
- [ ] Resolve all inputs to ticket + article
- [ ] Stage voice confirmed per ticket
- [ ] Code + resolution grounded
- [ ] Body rewritten; Image: captions inline
- [ ] validate_write → execute_approved_write verified
- [ ] Final batch table + screenshot list delivered
```

## Anti-patterns

- Ultra-short playbooks that omit the verified root cause
- Long articles with citation scaffolding and vague “menus may vary”
- `Image placeholder:` wording
- Screenshot URLs only in chat, missing from the article (or only at the end)
- Support jargon on **User Article** stage
- Overwriting user-uploaded images without an explicit ask
- Mutating unrelated production business data while editing KB text
