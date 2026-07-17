#!/usr/bin/env bash
# Verify the CLIs the dual-agent workflow depends on and print their resolved
# paths. Exits non-zero if a required tool cannot be resolved so the
# orchestrator can fail safe. Does NOT assume flag syntax; does NOT reinstall.
#
# Resolution order for each tool:  $<TOOL>_BIN env override -> PATH -> known
# fallback locations. The Codex CLI commonly ships inside the ChatGPT app
# bundle and is NOT on a login-shell PATH, hence the fallback.
set -euo pipefail

# Shared resolver — IDENTICAL discovery logic to the orchestrator (finding #4).
# Provides resolve_claude / resolve_codex plus the fallback arrays and the
# Claude Desktop versioned-path glob.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-resolve-agents.sh"

missing=0
report() {
  local label="$1" path="$2" name="$3"
  if [[ -n "$path" ]]; then
    printf '  [ok]   %-10s -> %s\n' "$label" "$path"
    "$path" --version 2>/dev/null | head -1 | sed 's/^/            version: /' || true
  else
    printf '  [MISS] %s not found (PATH or known fallbacks)\n' "$label"
    missing=1
  fi
}

CLAUDE_RESOLVED="$(resolve_claude "${CLAUDE_BIN:-}" || true)"
CODEX_RESOLVED="$(resolve_codex  "${CODEX_BIN:-}"  || true)"

echo "Dual-agent tool check:"
report "Claude CLI" "$CLAUDE_RESOLVED" claude
report "Codex CLI"  "$CODEX_RESOLVED"  codex

if [[ "$missing" -ne 0 ]]; then
  echo
  echo "A required CLI could not be resolved. Verify in the terminal you'll use:"
  echo "    command -v claude ; command -v codex"
  echo "If a tool exists but isn't on PATH (e.g. Codex inside ChatGPT.app), export"
  echo "its absolute path before running the orchestrator, e.g.:"
  echo "    export CODEX_BIN=/Applications/ChatGPT.app/Contents/Resources/codex"
fi

echo
echo "Flag discovery (verify before trusting in the orchestrator):"
if [[ -n "$CODEX_RESOLVED" ]]; then
  echo "  codex exec --help (first lines):"
  "$CODEX_RESOLVED" exec --help 2>/dev/null | head -20 | sed 's/^/    /' || \
    echo "    (codex exec --help not available)"
else
  echo "  Codex not resolved — 'codex exec' flags UNVERIFIED for this version."
fi

echo
if [[ "$missing" -ne 0 ]]; then
  echo "RESULT: missing required tool(s) — cannot run end-to-end until both"
  echo "        'claude' and 'codex' resolve (PATH, env override, or fallback)."
  exit 1
fi
echo "RESULT: all required tools resolved."
