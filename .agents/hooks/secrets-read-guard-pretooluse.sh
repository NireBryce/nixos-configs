#!/usr/bin/env bash
# PreToolUse hook (Read|Grep|Glob matcher). Denies read-type tool calls
# whose target is sops-nix secret material -- /run/secrets and
# /run/secrets.d -- the hook-side translation of `.agents/settings.json`'s
# `Read(...)` deny rules, which ZCode has no equivalent of (#458): its
# docs describe no permission rules, so without this hook only Claude
# Code gates those paths.
#
# A read tool returns the file contents into the conversation the same way
# `cat` does, so the bar is secrets-guard-pretooluse's: everything under
# those trees denies, and there is no metadata exemption because a Read
# has no metadata mode (`test -s`/`stat`/`ls -la` remain the Bash-side
# safe forms). String match on the requested path, exactly like the deny
# rules are -- a symlink elsewhere pointing into the tree is not
# resolved; the rules are string matchers, not a boundary
# (.agents/rules/agent-config.md). Edit/Write are not this hook's tools;
# secrets-guard-posttooluse watches their output.
#
# Fixture tests: flake/scripts/test_guards.py.
set -euo pipefail

# No jq: say so (JSON built by hand) instead of allowing silently -- the
# same fail-visible rule as secrets-guard-pretooluse.sh's header.
if ! command -v jq >/dev/null 2>&1; then
    cat >/dev/null
    printf '%s\n' '{"systemMessage":"secrets-read-guard: jq not on PATH, so this Read/Grep/Glob was NOT checked against /run/secrets. Install jq (packages-config/nix-utils/) to re-arm the guard."}'
    exit 0
fi

input=$(cat)
# Read takes file_path; Grep and Glob take path.
path=""
for key in file_path path; do
    v=$(jq -r --arg k "$key" '.tool_input[$k] // empty' <<<"$input")
    if [ -n "$v" ]; then
        path=$v
        break
    fi
done

case $path in
    /run/secrets|/run/secrets/*|/run/secrets.d|/run/secrets.d/*) ;;
    *) exit 0 ;;
esac

reason="This path is under /run/secrets or /run/secrets.d -- sops-nix's decrypted secret material. A read tool returns the contents into the conversation, the same leak `cat` would cause, and reading decrypted secrets into the conversation is barred (AGENTS.md Safety). To confirm a secret was deployed use Bash \`test -s <path>\`, \`stat <path>\`, or \`ls -la /run/secrets/\`; to list which secrets exist, \`just read-sops-names\` (names only)."
jq -n --arg reason "$reason" '{
    systemMessage: ("⛔ SECRET READ DENIED: " + $reason),
    hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: $reason,
        additionalContext: $reason
    }
}'
exit 0
