# Dual-agent workflow (Claude orchestrates, Codex executes)

This describes *how the two agents work together* on this repo. `CLAUDE.md`
(governance / Definition of Done) and any `SPEC.md` (technical source of truth)
take precedence on conflict — this file sits on top of them.

## Connecting (do this first in a new thread)

From a fresh Claude thread (or by hand), verify the link before dispatching
work:

```
scripts/agent-connect.sh
```

It resolves both CLIs and runs a live nonce round-trip against a real
`codex exec` process. PASS = connected. The executor (Codex) commonly ships
inside ChatGPT.app and is not on PATH; if it isn't found, export it:

```
export CODEX_BIN=/Applications/ChatGPT.app/Contents/Resources/codex
```

## Roles

**Claude Code — orchestrator & quality gate.** Reads the task and governance,
decomposes the work, issues a structured work order to Codex, reviews Codex's
plan/diff/report against requirements, decides ACCEPT / CORRECT / ESCALATE,
detects scope creep, and does the *final* requirement-level review. Claude
minimises direct implementation; it makes only trivial edits to
orchestration/task-metadata files where re-invoking Codex would be pure
overhead.

**Codex — execution engine.** Detailed repo analysis, production-code changes,
tests, running validation, debugging, targeted refactors, structured reports,
and logically-scoped commits. Codex does the token-heavy work in an isolated
git worktree.

**Human — exception handler.** Normally only: canonical data writes/migrations,
credential/token handling, destructive or force git ops, production/infra
changes, major dependency upgrades, ambiguous business requirements, unresolved
Claude↔Codex disagreement, and the final merge (auto-merge off by default).

## Leadership & how the two agents disagree

**Claude leads.** As orchestrator, Claude proposes a concrete solution and
drives it — it does not hand every open question back to the human. Within the
autonomous envelope (see Risk + Safety boundary) Claude decides, sets scope,
sequences work, resolves routine ambiguity with a stated assumption, and only
escalates the genuinely human-only matters above.

**Codex is a senior engineer, not an order-taker.** A work order is a starting
position, not gospel. Codex is expected to **push back** — with reasoning and a
concrete counter-proposal — when an instruction is wrong, unsafe, out of scope,
based on a mistaken premise, or simply not the best approach.

**Resolving a disagreement:** Codex raises the objection in its report → Claude
weighs it and either revises the order or restates it with justification → if
still split after one honest exchange, Claude escalates to the human with both
positions. Neither just overrides nor silently complies.

## Control flow

```
Human supplies task  ->  Claude reads task + governance
  ->  Claude writes .agent-output/codex-work-order.md
  ->  Codex plans, implements, validates, writes implementation report
  ->  Claude reviews task + diff + report + validation output
  ->  Claude decides: ACCEPT | CORRECT (one order) | ESCALATE
        CORRECT -> Codex fixes -> re-validate -> Claude final review
  ->  final report | human escalation
```

## Cycle limit

At most **two** Codex rounds: (1) implement → validate → review; (2) one
correction order → fix → validate → final review. After round 2: ACCEPT if
requirements + validation pass, else ESCALATE. No unlimited loop.

## Machine-readable decision protocol

Claude's review ends with **exactly one** final line matching
`^DECISION: (ACCEPT|CORRECT|ESCALATE)$`. `CORRECT` also writes
`.agent-output/codex-correction-order.md`; `ESCALATE` also writes
`.agent-output/human-escalation.md`. Missing/duplicate/inconsistent decision
lines fail safe by escalating.

## Review standard (Claude)

Classify findings BLOCKER / MAJOR / MINOR / SUGGESTION.
- **Accept** when: no BLOCKER, no MAJOR, required validation passes (pinned
  correctness tests *ran*, not skipped), in scope, acceptance criteria met, no
  prohibited operation occurred.
- **Correct** when: ≥1 valid BLOCKER/MAJOR fixable safely in scope.
- MINOR/SUGGESTION do not block unless they violate governance, create a likely
  regression, or contradict an explicit acceptance criterion.

## Risk classification

- **LOW** — docs, isolated tests, small bug fixes. Proceed automatically.
- **MEDIUM** — multi-file behaviour changes, data transforms, same-major-version
  dep changes. Proceed automatically; final merge stays human-controlled.
- **HIGH** — schema, canonical-data-touching logic, auth, tokens, migrations,
  deletion, infra, deployment. **Escalate before** the risky op.

## Model routing (cost tiering)

Codex runs on a **two-tier** model policy set in `agent-workflow.config.sh`.
Because Claude has already decomposed, scoped, and gated the work, most work
orders are clear and testable and run fine on the cheaper balanced model. The
stronger-reasoning model is an escalation tier, not the everyday default (it is
~2× the token price for the same context window).

| Situation | Model |
|---|---|
| LOW / MEDIUM: tests, ordinary bugs, docs, UI, config, clear-scope refactors | `CODEX_MODEL` (default, e.g. Terra, reasoning high) |
| Correction round (a task that failed validation once → needs deeper reasoning) | `CODEX_MODEL_ESCALATED` — **applied automatically** by the orchestrator |
| HIGH-risk: scoring/canonical-data logic, migrations, auth/tokens, schema, major perf | `CODEX_MODEL_ESCALATED`, launched explicitly after human approval |
| Reasoned Claude↔Codex technical dispute unresolved on the default model | escalate to `CODEX_MODEL_ESCALATED` for re-analysis |

Launch a HIGH-risk task straight on the escalation model:

```
CODEX_MODEL="$CODEX_MODEL_ESCALATED" scripts/agent-orchestrator.sh
```

The rule is **"default cheap, escalate on failure/risk"** — never a single model
for everything. If the cheaper model routinely needs a full second round, the
saving evaporates; track first-pass rate and revisit the default.

## Definition of "passing"

Whatever `CLAUDE.md` / the project's config (`agent-workflow.config.sh`
→ `VALIDATION_CMD`) define. Skipped correctness tests are **not** a pass. Do
not redefine the gate as part of a task.

## Safety boundary (autonomous mode)

The orchestrator MAY: create task branches/worktrees, edit files in the Codex
worktree, run tests/preview, commit, generate reports, run one correction
cycle. It MUST NOT automatically: push to protected branches, force-push, merge,
deploy, write canonical data, run migrations, delete user data, modify
credentials/tokens, or major-bump dependencies. Any of those → ESCALATE.
Auto-merge is **off** by default; the run stops at ACCEPT and reports branch,
commit, validation, review result, and changed files. The human merges.

## Isolation between projects

Each project is self-contained: its own repo, its own `worktrees/`, and its own
`.agent-output/` exchange dir (all gitignored). Projects do not share state, so
multiple projects on the same machine never interfere. The only shared thing is
the machine's installed Codex/Claude CLIs, discovered at runtime by
`scripts/lib-resolve-agents.sh`.
