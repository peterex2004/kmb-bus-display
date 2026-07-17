# Task

Current work contract for the dual-agent workflow. Claude (orchestrator)
reads this first and may update it from a natural-language request, but must
not invent material requirements. SPEC.md remains the technical source of
truth; this file only scopes one task at a time.

## Objective
<!-- The feature, fix, or refactor being requested. One paragraph. -->

## Background
<!-- Why this is needed. Link to SPEC.md sections / prior decisions. -->

## Scope
<!-- Files / modules / systems that MAY change. -->

## Out of scope
<!-- Changes that MUST NOT be made in this task. -->

## Functional requirements
<!-- Observable behaviour the implementation must produce. -->

## Non-functional requirements
<!-- Correctness (golden-value), performance, i18n (en/zh), compatibility. -->

## Acceptance criteria
<!-- Objective, checkable completion conditions. -->

## Required validation
<!-- Exact commands. Default gate for this repo:
     node scripts/validate-js.js   (parse-checks the inline <script> in index.html)
     Plus, if UI changed: manual/preview check in browser (no build step exists).
     Do NOT substitute a weaker definition of "passing". -->
node scripts/validate-js.js

## Risk classification
<!-- LOW | MEDIUM | HIGH  (see docs/agent-workflow.md §Risk). -->

## Human approval requirements
<!-- Any step needing a human: canonical DB writes/migrations, token
     handling, sync against live Garmin, destructive git, dep major bumps. -->

## Open questions
<!-- Unresolved requirements needing human judgment. Empty = ready to run. -->
