#!/usr/bin/env bash
# PreToolUse hook (Bash matcher). Alarms while the guards' ZCode detection
# is disarmed. git-guard's deny-under-ZCode and just-guard's skip-under-ZCode
# both key on camelCase fields in the hook payload (hookEventName/
# transcriptPath) -- a shape a ZCode upgrade can change, and changing it
# fails OPEN: ZCode sessions would silently fall back to ask-as-allow, the
# exact behaviour the deny split exists to prevent (#448/#458).
#
# The payload fields and the environment are independent signals, so they
# cross-check: ZCode injects ZCODE_PROJECT_DIR into the hook environment,
# Claude Code does not. When the environment says ZCode but the payload
# carries none of the camelCase fields, one of two things is true and this
# hook cannot tell which:
#   - Claude Code was started from a ZCode-spawned shell and inherited the
#     variable -- harmless, this is Claude Code behaving as normal; or
#   - a ZCode upgrade changed the payload shape -- then every ZCode-specific
#     behaviour above is disarmed until the detection is updated.
# Either way it says so on every guarded call (additionalContext for the
# model; systemMessage for the human, which only Claude Code shows -- ZCode
# drops it for PreToolUse) instead of staying silent, and the
# agent-config rule's live hook check is what settles it. Advisory only:
# nothing is denied or blocked here. Bash matcher because the disarmed
# behaviour is git-guard's and just-guard's, both Bash guards.
#
# Fixture tests: flake/scripts/test_guards.py.
set -euo pipefail

# No jq: say so (JSON built by hand) instead of allowing silently -- the
# same fail-visible rule as secrets-guard-pretooluse.sh's header.
if ! command -v jq >/dev/null 2>&1; then
    cat >/dev/null
    printf '%s\n' '{"systemMessage":"zcode-canary: jq not on PATH, so the ZCode payload-shape cross-check was NOT run. Install jq (packages-config/nix-utils/) to re-arm the guard."}'
    exit 0
fi

input=$(cat)
zcode_payload=$(jq -r 'if has("hookEventName") or has("transcriptPath") then "1" else empty end' <<<"$input")

# Both signals agree on "not ZCode" (Claude Code, plain), or both on
# "ZCode" (payload fields present, variable injected): nothing to say.
[ -n "${ZCODE_PROJECT_DIR:-}" ] || exit 0
[ -z "$zcode_payload" ] || exit 0

reason="This hook's environment sets ZCODE_PROJECT_DIR but the payload carries none of the camelCase fields (hookEventName/transcriptPath) the guards use to detect ZCode. Either Claude Code inherited the variable from a ZCode-spawned shell -- then this is normal Claude Code behaviour, ignore -- or a ZCode upgrade changed the hook payload shape and the deny-under-ZCode logic is disarmed (an ask would silently allow there). Run the live hook check per .agents/rules/agent-config.md and update the payload detection in git-guard-pretooluse.sh and just-guard-pretooluse.sh; do not treat this session's guards as holding until then."
jq -n --arg reason "$reason" '{
    systemMessage: ("⚠️  ZCODE DETECTION MISMATCH: " + $reason),
    hookSpecificOutput: {
        hookEventName: "PreToolUse",
        additionalContext: $reason
    }
}'
exit 0
