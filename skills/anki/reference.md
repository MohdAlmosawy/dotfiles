# Anki MSc — reference

Host paths live in the `devices` skill. Resolve them there. Do not copy a path from this file.

## Courses

| Code | Title | Tag | Lecture day |
|------|-------|-----|-------------|
| ITML 601 | Advanced AI & NLP | `course::601` | Monday |
| ITML 602 | Machine Learning | `course::602` | Wednesday |
| ITML 603 | Research Methodology | `course::603` | Tuesday |

601 roadmap: weeks 1–7 `phase::symbolic` (search, knowledge representation, fuzzy, expert systems, HMM). Weeks 8–14 `phase::nlp` (embeddings, transformers, RAG). Week 15 project.

## Presets

| Preset | id | Role |
|--------|-----|------|
| Default | `1` | Stock fallback. Leave alone |
| CAIE Main | `1771010340056` | Pre-MSc certificate. Leave alone |
| Long Term Retention | `1772093537700` | Daily driver |
| Exam Mode | `1771586070588` | Temporary exam overlay |

### Long Term Retention

- Learn / relearn: `10m` / `10m`
- New/day: `30`. Reviews: `9999`
- Desired retention: `0.90`. Max interval: `36500`
- Bury new, review, and interday siblings
- Review order: retrievability ascending
- FSRS-6 stock 21 weights. Timer off

### Exam Mode

- Learn / relearn: `10m` / `10m` (never `1d`)
- New/day: `50`. Reviews: `9999`
- Desired retention: `0.94`. Max interval: `21`
- Reviews before new cards
- Timer on (75s, stop on answer)
- Use for one to two weeks before a midterm or final, then revert

Deck `kind` protobuf: `KindContainer.normal.config_id` is the preset id. `MCs*` decks use Long Term Retention unless they are intentionally on Exam Mode.

## Topics

601 in use: `topic::ai-foundations`, `topic::agents`, `topic::symbolic-ai`, `topic::search-foundations`, `topic::and-or-search`.

601 later, as the syllabus reaches them: `topic::adversarial-search`, `topic::knowledge-rep`, `topic::fuzzy-logic`, `topic::text-preprocess`, `topic::statistical-nlp`, `topic::sequence-labeling`, `topic::embeddings`, `topic::transformers`, `topic::contextual-lms`, `topic::downstream-nlp`, `topic::rag-llms`, `topic::ai-ethics`.

602 in use: `topic::supervised`, `topic::unsupervised`, `topic::linear-regression`, `topic::regression-metrics`, `topic::logistic-regression`.

603 later: `topic::research-design` and `phase::methods` if needed.

Phases: `phase::symbolic`, `phase::nlp`, `phase::intro`.

Types: `type::def`, `type::contrast`, `type::why`, `type::formula`, `type::algo`.

## Placement

| Content | Deck |
|---------|------|
| AI taxonomy, agents, policy, symbolic vs non-symbolic | `601-NLP :: 00) Introduction` |
| State space, node vs state, heuristics, A* | `601-NLP :: 01) Search Foundations` |
| AND/OR graphs, AO*, games, minimax, alpha–beta | `601-NLP :: 02) Adversarial Search` |
| What ML is, supervised vs unsupervised, linear regression, MSE / RMSE / R² | `602-ML :: 00) Introduction & Linear Regression` |
| Logistic regression, sigmoid, log-likelihood, gradient descent, precision / accuracy | `602-ML :: 01) Logistic Regression` |
| Later blocks | matching `NN) Title` subdeck |

## Searches

| Goal | Search |
|------|--------|
| This week | `tag:week::01` |
| Weak topic | `tag:flag::weak` |
| 601 midterm | `tag:course::601 tag:phase::symbolic` |
| Whole course | `tag:course::601` |
| Definitions | `tag:type::def` |
| Teaching candidates | `tag:flag::teach` |

## Technical

- Schema v18. `deck_config.config`, `decks.common`, and `decks.kind` are protobuf.
- Deck hierarchy uses `\x1f` in the database. The UI shows `::`.
- FSRS is on. `fsrsShortTermWithStepsEnabled` is false. Keep steps same-day.
- Note tags are the source of truth. Anki "Check Database" can prune unused tag names.
- Note type: Basic (optional reversed card).

FSRS-6 default weights (21):

```
0.212, 1.2931, 2.3065, 8.2956, 6.4133,
0.8334, 3.0194, 0.001, 1.8722,
0.1666, 0.796, 1.4835, 0.0614, 0.2629,
1.6483, 0.6014, 1.8729, 0.5425,
0.0912, 0.0658, 0.1542
```
