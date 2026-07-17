#!/usr/bin/env bash
# Per-project dual-agent configuration (committed). Sourced by the orchestrator.
# Fill these in for THIS project; sane defaults apply when left as-is.

# Command that runs the project's full validation gate (must exit non-zero on
# failure). The false-green guard also fails if it prints "N skipped".
VALIDATION_CMD="node scripts/validate-js.js"

# Optional: a single test file/target that MUST run and pass (a golden-value
# regression). Leave empty if the project has no such pinned correctness test.
GOLDEN_TEST=""

# Optional: a shell command to prepare per-worktree runtime state before Codex
# runs (e.g. copying a read-only fixture DB into the worktree). $CODEX_WORKTREE
# is exported when this runs. Leave empty if no runtime prep is needed.
#   e.g. RUNTIME_PREP_CMD='scripts/prepare-worktree-runtime.sh "$CODEX_WORKTREE"'
RUNTIME_PREP_CMD=""

# Worktree + branch the executor uses (defaults are usually fine).
# CODEX_WORKTREE="$PWD/worktrees/codex-task"
# CODEX_BRANCH="agent/codex"

# Codex sandbox flags. workspace-write confines writes to the worktree.
# CODEX_EXEC_FLAGS="--sandbox workspace-write"

# --- Model routing (cost tiering) -----------------------------------------
# Two-tier policy for THIS account (verified live against this Codex CLI
# install — bare codenames like "luna"/"sol" are rejected; the full
# "gpt-5.6-<name>" form is required):
#
#   CODEX_MODEL + CODEX_REASONING_EFFORT
#     default executor — LOW/MEDIUM tasks (tests, bugs, docs, UI, config,
#     clear-scope refactors). gpt-5.6-luna at xhigh reasoning effort.
#   CODEX_MODEL_ESCALATED + CODEX_REASONING_EFFORT_ESCALATED
#     used automatically for the correction round (a task that failed once
#     needs a stronger model); also launch HIGH-risk / very complicated tasks
#     (scoring formulas, migrations, auth/tokens, schema, major perf) on it
#     explicitly:
#     `CODEX_MODEL=$CODEX_MODEL_ESCALATED CODEX_REASONING_EFFORT=$CODEX_REASONING_EFFORT_ESCALATED scripts/agent-orchestrator.sh`
CODEX_MODEL="${CODEX_MODEL:-gpt-5.6-luna}"
CODEX_REASONING_EFFORT="${CODEX_REASONING_EFFORT:-xhigh}"
CODEX_MODEL_ESCALATED="${CODEX_MODEL_ESCALATED:-gpt-5.6-sol}"
CODEX_REASONING_EFFORT_ESCALATED="${CODEX_REASONING_EFFORT_ESCALATED:-high}"
