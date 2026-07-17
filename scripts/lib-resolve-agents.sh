#!/usr/bin/env bash
# Shared CLI resolver for the dual-agent workflow. Sourced by BOTH
# scripts/check-agent-tools.sh and scripts/agent-orchestrator.sh so tool
# discovery is byte-identical in both (no drift — see review finding #4).
# Sourcing only defines functions + fallback arrays; no side effects.
#
# Resolution order for each tool:
#   $<TOOL>_BIN env override -> PATH -> static fallback -> (Claude only) a glob
#   over Claude Desktop's versioned install. Env override always wins, so a
#   machine-local .claude/agent-workflow.local.sh can pin CLAUDE_BIN/CODEX_BIN.

# Static fallbacks (extend as needed; env override wins).
CODEX_FALLBACKS=( "/Applications/ChatGPT.app/Contents/Resources/codex" )
CLAUDE_FALLBACKS=(
  "$HOME/.claude/local/claude"
  "/opt/homebrew/bin/claude"
  "/usr/local/bin/claude"
)
# Claude Desktop ships a *versioned* CLI, e.g.
#   ~/Library/Application Support/Claude/claude-code/2.1.111/claude.app/Contents/MacOS/claude
# We match it with a glob and pick the newest, so no personal version-pinned
# path is committed (the version dir changes on every Claude update).
CLAUDE_GLOBS=(
  "$HOME/Library/Application Support/Claude/claude-code/"*"/claude.app/Contents/MacOS/claude"
)

# resolve_agent_bin <override> <name> <fallback...> -> abs path on stdout | rc!=0
resolve_agent_bin() {
  local override="$1" name="$2"; shift 2
  if [[ -n "$override" ]]; then
    command -v "$override" 2>/dev/null && return 0
    [[ -x "$override" ]] && { echo "$override"; return 0; }
  fi
  command -v "$name" 2>/dev/null && return 0
  local f
  for f in "$@"; do [[ -x "$f" ]] && { echo "$f"; return 0; }; done
  return 1
}

# resolve_claude_glob -> newest executable matching CLAUDE_GLOBS | rc!=0
# No `shopt nullglob` needed: an unmatched glob stays literal and is dropped by
# the `-x` test below, so this stays portable across bash/zsh.
resolve_claude_glob() {
  local newest="" f
  for f in "${CLAUDE_GLOBS[@]}"; do
    [[ -x "$f" ]] || continue
    [[ -z "$newest" || "$f" -nt "$newest" ]] && newest="$f"
  done
  [[ -n "$newest" ]] && { echo "$newest"; return 0; }
  return 1
}

# resolve_claude [override] -> abs path | rc!=0   (adds the Desktop-glob step)
resolve_claude() {
  resolve_agent_bin "${1:-}" claude "${CLAUDE_FALLBACKS[@]}" && return 0
  resolve_claude_glob && return 0
  return 1
}

# resolve_codex [override] -> abs path | rc!=0
resolve_codex() {
  resolve_agent_bin "${1:-}" codex "${CODEX_FALLBACKS[@]}"
}
