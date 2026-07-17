#!/usr/bin/env bash
# Generic dual-agent orchestrator: Claude decides, Codex executes.
#
#   task (docs/task.md)
#     -> Claude writes codex-work-order.md (into $OUT)
#     -> Codex implements + validates + reports (in its worktree)
#     -> orchestrator INDEPENDENTLY re-validates (false-green guard)
#     -> Claude reviews the real diff -> DECISION: ACCEPT|CORRECT|ESCALATE
#     -> (optional) one Codex correction cycle -> re-validate -> final review
#
# Stops at ACCEPT — it does NOT merge (auto-merge off by default). Project-
# specific values (validation command, optional golden test, optional runtime
# prep) come from ./agent-workflow.config.sh so this script stays generic.
# See docs/agent-workflow.md for the full model and safety boundary.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# --- project configuration (with safe defaults) ---------------------------
# Machine-local overrides (gitignored), e.g. a shared exchange folder or pinned
# CLAUDE_BIN/CODEX_BIN.
[[ -f "$ROOT/.claude/agent-workflow.local.sh" ]] && source "$ROOT/.claude/agent-workflow.local.sh"
# Per-project config (committed): VALIDATION_CMD, GOLDEN_TEST, RUNTIME_PREP_CMD,
# RUNTIME_DB_ENV/RUNTIME_DB, CODEX_WORKTREE, CODEX_BRANCH.
[[ -f "$ROOT/agent-workflow.config.sh" ]] && source "$ROOT/agent-workflow.config.sh"

OUT="${AGENT_OUTPUT_DIR:-$ROOT/.agent-output}"
TASK="$ROOT/docs/task.md"
CODEX_WORKTREE="${CODEX_WORKTREE:-$ROOT/worktrees/codex-task}"
CODEX_BRANCH="${CODEX_BRANCH:-agent/codex}"
AUTO_MERGE="${AUTO_MERGE:-false}"
CODEX_EXEC_FLAGS="${CODEX_EXEC_FLAGS:---sandbox workspace-write}"
# Model routing (cost tiering): cheaper balanced model by default; the
# correction round auto-escalates to the stronger model (see docs).
CODEX_MODEL="${CODEX_MODEL:-gpt-5.6-terra}"
CODEX_MODEL_ESCALATED="${CODEX_MODEL_ESCALATED:-gpt-5.6-sol}"
VALIDATION_CMD="${VALIDATION_CMD:-make test}"
GOLDEN_TEST="${GOLDEN_TEST:-}"                 # empty => no golden-specific gate
RUNTIME_PREP_CMD="${RUNTIME_PREP_CMD:-}"       # empty => no runtime prep step
VALIDATION_LOG="$OUT/validation.log"

mkdir -p "$OUT"

log() { printf '\n=== %s ===\n' "$*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

source "$ROOT/scripts/lib-resolve-agents.sh"

resolve_bins() {
  CLAUDE_BIN="$(resolve_claude "${CLAUDE_BIN:-}" || true)"
  CODEX_BIN="$(resolve_codex   "${CODEX_BIN:-}"  || true)"
}

check_tools() {
  log "Checking agent tools"
  "$ROOT/scripts/check-agent-tools.sh" || die "required CLI missing (see above)"
  resolve_bins
  [[ -n "$CODEX_BIN" ]] || die "codex not resolvable"
}

check_repository() {
  log "Checking repository state"
  [[ -f "$TASK" ]] || die "missing task contract: $TASK"
  grep -q '[^[:space:]]' "$TASK" || die "task contract is empty: fill $TASK"
  if [[ -n "$(git -C "$ROOT" status --porcelain)" ]]; then
    echo "WARNING: main checkout has uncommitted changes. Agents operate in" >&2
    echo "         worktrees; commit or stash the main checkout first." >&2
  fi
}

prepare_codex_worktree() {
  log "Preparing Codex worktree"
  git -C "$ROOT" branch "$CODEX_BRANCH" >/dev/null 2>&1 || true
  if ! git -C "$ROOT" worktree list --porcelain | grep -q "$CODEX_WORKTREE"; then
    git -C "$ROOT" worktree add "$CODEX_WORKTREE" "$CODEX_BRANCH"
  fi
  if [[ -n "$RUNTIME_PREP_CMD" ]]; then
    log "Preparing worktree runtime"
    ( cd "$ROOT" && CODEX_WORKTREE="$CODEX_WORKTREE" bash -c "$RUNTIME_PREP_CMD" ) \
      || die "runtime prep failed"
  fi
}

# Claude (reviewer) runs from $ROOT, granted write to the shared exchange dir.
run_claude() { ( cd "$ROOT" && "$CLAUDE_BIN" --add-dir "$OUT" -p "$1" ); }
# Codex writes confined to the worktree; --add-dir grants the main .git (worktree
# refs live there) and the exchange dir so it can commit + drop reports.
run_codex()  { ( cd "$CODEX_WORKTREE" \
                 && "$CODEX_BIN" exec $CODEX_EXEC_FLAGS -m "$CODEX_MODEL" \
                      --add-dir "$ROOT/.git" --add-dir "$OUT" "$1" ); }

# --- false-green guard: independently re-run validation --------------------
run_validation_gate() {
  log "Independent validation gate (false-green guard)"
  set +e
  ( cd "$CODEX_WORKTREE" && bash -c "$VALIDATION_CMD" ) 2>&1 | tee "$VALIDATION_LOG"
  local rc=${PIPESTATUS[0]}
  set -e
  [[ $rc -eq 0 ]] || { echo "GATE: validation failed (rc=$rc)"; return 1; }
  if grep -qE '[0-9]+ skipped' "$VALIDATION_LOG"; then
    echo "GATE: tests were SKIPPED — correctness not honoured."
    return 2
  fi
  if [[ -n "$GOLDEN_TEST" ]]; then
    set +e
    ( cd "$CODEX_WORKTREE" && python3 -m pytest -q "$GOLDEN_TEST" ) \
      2>&1 | tee -a "$VALIDATION_LOG" | grep -qE '[1-9][0-9]* passed'
    local grc=$?
    set -e
    [[ $grc -eq 0 ]] || { echo "GATE: golden regression ($GOLDEN_TEST) did not pass/run."; return 3; }
  fi
  echo "GATE: passed."
  return 0
}

read_decision() {
  local f="$1" count
  [[ -f "$f" ]] || { echo INVALID; return; }
  count="$(grep -cE '^DECISION: (ACCEPT|CORRECT|ESCALATE)$' "$f" || true)"
  [[ "$count" -eq 1 ]] || { echo INVALID; return; }
  grep -oE '^DECISION: (ACCEPT|CORRECT|ESCALATE)$' "$f" | awk '{print $2}'
}

resolve_decision() {
  local review="$1" gate_ok="$2" d
  d="$(read_decision "$review")"
  case "$d" in
    INVALID)  echo ESCALATE; return ;;
    CORRECT)  [[ -f "$OUT/codex-correction-order.md" ]] || { echo ESCALATE; return; } ;;
    ESCALATE) : ;;
    ACCEPT)   [[ "$gate_ok" == "1" ]] || { echo ESCALATE; return; } ;;
  esac
  echo "$d"
}

create_work_order() {
  log "Claude: generating Codex work order"
  [[ -n "$CLAUDE_BIN" ]] || die "claude not resolvable (needed for automated work-order generation)"
  run_claude "Read docs/task.md, and any SPEC.md/CLAUDE.md/AGENTS.md present. You are the \
orchestrator. Write a concise Codex work order to $OUT/codex-work-order.md using the section \
format in docs/agent-workflow.md (objective, authoritative files, files to inspect, allowed \
changes, prohibited changes, required implementation, required tests, validation, risk controls, \
report format, completion conditions). Keep it short. Do NOT modify production code." >/dev/null
  [[ -f "$OUT/codex-work-order.md" ]] || die "work order not produced"
}

codex_implement() {
  log "Codex: implement + validate + report (worktree)"
  run_codex "Read docs/task.md, $OUT/codex-work-order.md, and any SPEC.md/CLAUDE.md/AGENTS.md. \
Inspect the repo, implement within the work order's allowed scope, add/update tests, run the \
project's validation, and commit logically-scoped changes. Write \
$OUT/codex-implementation-report.md per docs/agent-workflow.md. Do NOT claim done if validation \
failed or tests were skipped."
}

claude_review() {
  local phase="$1" outfile="$2" gate_ok="$3"
  log "Claude: $phase review"
  [[ -n "$CLAUDE_BIN" ]] || die "claude not resolvable (needed for automated review)"
  run_claude "You are the orchestrator/quality gate. Review the Codex work on branch \
$CODEX_BRANCH. Read docs/task.md, the work order, the real git diff ($CODEX_BRANCH vs main), \
$OUT/codex-implementation-report.md and $OUT/validation.log (independent gate: \
$( [[ $gate_ok == 1 ]] && echo PASSED || echo FAILED )). Classify findings \
BLOCKER/MAJOR/MINOR/SUGGESTION. Write your review to $outfile. If CORRECT, also write \
$OUT/codex-correction-order.md. If ESCALATE, also write $OUT/human-escalation.md. End with \
EXACTLY one line: 'DECISION: ACCEPT' or 'DECISION: CORRECT' or 'DECISION: ESCALATE'. If the \
validation gate FAILED you must not ACCEPT." | tee "$outfile" >/dev/null
}

codex_correct() {
  # A task that failed round 1 needs deeper reasoning: escalate the model for
  # the single correction cycle (dynamic scope makes run_codex see this).
  local CODEX_MODEL="$CODEX_MODEL_ESCALATED"
  log "Codex: single correction cycle (model: $CODEX_MODEL)"
  run_codex "Read $OUT/codex-correction-order.md. Verify each finding independently; fix valid \
BLOCKER/MAJOR (and low-risk in-scope MINOR); add regression tests for fixed defects; document \
rejected findings with a reason. Re-run the project's validation. Commit corrections separately. \
Update $OUT/codex-fix-report.md."
}

final_summary() {
  log "ACCEPTED — summary"
  {
    echo "# Dual-agent run summary"
    echo "- Branch:  $CODEX_BRANCH"
    echo "- Commit:  $(git -C "$CODEX_WORKTREE" rev-parse --short HEAD 2>/dev/null || echo n/a)"
    echo "- Validation gate: PASSED (see $OUT/validation.log)"
    echo "- Changed files:"
    git -C "$ROOT" diff --name-only "main..$CODEX_BRANCH" 2>/dev/null | sed 's/^/    /'
    echo "- Auto-merge: $AUTO_MERGE (stops before merge; human merges)."
  } | tee "$OUT/final-review.md"
}

escalate() {
  log "ESCALATED to human"
  [[ -f "$OUT/human-escalation.md" ]] && echo "See $OUT/human-escalation.md" \
    || echo "No escalation file — failed safe. See $VALIDATION_LOG and reviews in $OUT."
  exit 2
}

dry_run() {
  resolve_bins
  [[ -n "$CLAUDE_BIN" ]] || die "claude not resolvable in this terminal"
  log "Headless Claude dry run"
  local resp dec
  resp="$("$CLAUDE_BIN" -p "Reply with EXACTLY one line and nothing else: 'DECISION: ACCEPT'")"
  printf '%s\n' "$resp"
  local tmp; tmp="$(mktemp)"; printf '%s\n' "$resp" >"$tmp"
  dec="$(read_decision "$tmp")"; rm -f "$tmp"
  [[ "$dec" == "ACCEPT" ]] && echo "Dry run OK." || { echo "Dry run FAILED to parse a decision line." >&2; exit 1; }
}

main() {
  [[ "$AUTO_MERGE" == "false" ]] || die "AUTO_MERGE must be false"
  check_tools
  check_repository
  prepare_codex_worktree
  create_work_order
  codex_implement
  local gate_ok=0; run_validation_gate && gate_ok=1
  claude_review "first" "$OUT/claude-review.md" "$gate_ok"
  case "$(resolve_decision "$OUT/claude-review.md" "$gate_ok")" in
    ACCEPT)   [[ $gate_ok == 1 ]] && final_summary || escalate ;;
    CORRECT)
      codex_correct
      local gate2=0; run_validation_gate && gate2=1
      claude_review "final" "$OUT/final-review-decision.md" "$gate2"
      case "$(resolve_decision "$OUT/final-review-decision.md" "$gate2")" in
        ACCEPT) [[ $gate2 == 1 ]] && final_summary || escalate ;;
        *)      escalate ;;
      esac ;;
    *)        escalate ;;
  esac
}

case "${1:-}" in
  --dry-run) dry_run ;;
  *)         main "$@" ;;
esac
