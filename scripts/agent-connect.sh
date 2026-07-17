#!/usr/bin/env bash
# One-command connection check for the Claude<->Codex dual-agent workflow.
#
# Run this FIRST from any new Claude thread (or by hand) to prove the two
# agents can actually talk on THIS machine, before dispatching real work:
#
#     scripts/agent-connect.sh
#
# It resolves both CLIs, then does a live, verifiable round-trip: it generates
# a fresh OS-random nonce, hands it to a real `codex exec` process, and checks
# that Codex echoes the nonce reversed. A correct reversal of a just-generated
# random value can only come from a live Codex run (it can't be pre-baked), so
# a PASS is real evidence of connectivity, not a hard-coded string.
#
# Exit 0 = connected & verified. Non-zero = not connected (message says why).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib-resolve-agents.sh"

# Optional machine-local overrides (gitignored): can pin CLAUDE_BIN/CODEX_BIN.
[[ -f "$ROOT/.claude/agent-workflow.local.sh" ]] && source "$ROOT/.claude/agent-workflow.local.sh"

CLAUDE_BIN="$(resolve_claude "${CLAUDE_BIN:-}" || true)"
CODEX_BIN="$(resolve_codex  "${CODEX_BIN:-}"  || true)"

echo "=== Dual-agent connection check ==="
printf '  Claude CLI: %s\n' "${CLAUDE_BIN:-<NOT FOUND>}"
printf '  Codex CLI:  %s\n' "${CODEX_BIN:-<NOT FOUND>}"

if [[ -z "$CODEX_BIN" ]]; then
  echo
  echo "FAIL: Codex CLI not resolvable. It usually ships inside ChatGPT.app:"
  echo "    export CODEX_BIN=/Applications/ChatGPT.app/Contents/Resources/codex"
  echo "  then re-run. (Claude is optional here; the executor is Codex.)"
  exit 1
fi

# --- version probe (best-effort; proves the binary actually runs) ----------
CODEX_VER="$("$CODEX_BIN" --version 2>/dev/null | head -1 || true)"
printf '  Codex version: %s\n' "${CODEX_VER:-<unknown>}"

# --- live nonce round-trip -------------------------------------------------
if command -v openssl >/dev/null 2>&1; then
  NONCE="$(openssl rand -hex 5)"
else
  NONCE="$(od -An -N5 -tx1 /dev/urandom | tr -d ' \n')"
fi
EXPECTED="$(printf '%s' "$NONCE" | rev)"

echo
echo "  Nonce (OS-random, generated just now): $NONCE"
echo "  Dispatching a live Codex round-trip (read-only sandbox)..."

PROMPT="You are Codex in a dual-agent workflow with Claude. Reverse this string \
character-by-character and print EXACTLY one line, nothing else, in the form \
'NONCE_REVERSED: <value>'. String: ${NONCE}"

RAW="$( "$CODEX_BIN" exec --sandbox read-only "$PROMPT" 2>/dev/null || true )"
GOT="$(printf '%s\n' "$RAW" | grep -oE 'NONCE_REVERSED: *[0-9a-fA-F]+' | tail -1 | sed -E 's/NONCE_REVERSED: *//')"

echo "  Expected reversed: $EXPECTED"
echo "  Codex returned:    ${GOT:-<none parsed>}"
echo

if [[ -n "$GOT" && "$GOT" == "$EXPECTED" ]]; then
  echo "RESULT: PASS — Codex is connected and answered a live challenge correctly."
  echo "        You can now dispatch work orders (see docs/agent-workflow.md)."
  exit 0
fi

echo "RESULT: FAIL — no correct live response from Codex."
echo "  The binary resolved but did not return the expected reversed nonce."
echo "  Re-run with the raw log for diagnosis:"
echo "    \"$CODEX_BIN\" exec --sandbox read-only 'reverse: $NONCE'"
exit 2
