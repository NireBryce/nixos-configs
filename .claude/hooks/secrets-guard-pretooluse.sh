#!/usr/bin/env bash
# PreToolUse hook (Bash matcher). Deterministic guard for the exact mistake
# documented in .claude/skills/secrets-hygiene/SKILL.md: on 2026-08-26 a bare
# `sops -d secrets.yaml` dumped the whole plaintext file -- tailscale_key and
# atuin_key included -- into the transcript, when only an exit-code check was
# needed. This is a pattern match, not a judgment call, so it runs every time
# rather than depending on the model remembering to be careful.
#
# Two things trip it:
#   1. `sops -d`/`sops --decrypt` with no `--extract` and no `>/dev/null` --
#      prints the entire decrypted file.
#   2. `cat`/`bat`/`less`/`more`/`head`/`tail` reading a path under
#      /run/secrets/ -- prints a live decrypted secret's contents.
# Both ask for confirmation rather than hard-denying: there's a real
# alternative for each (see the reason text), but a rare legitimate case
# (e.g. actually needing the whole file) shouldn't be flatly impossible.
set -euo pipefail

input=$(cat)
command=$(jq -r '.tool_input.command // empty' <<<"$input")

reason=""

if grep -qE '\bsops\b' <<<"$command" && grep -qE '(\s|^)-d\b|--decrypt\b' <<<"$command"; then
    if ! grep -qE -- '--extract\b' <<<"$command"; then
        if ! grep -qE '>\s*/dev/null' <<<"$command"; then
            reason="Bare 'sops -d' prints the WHOLE decrypted secrets.yaml into the transcript -- this is exactly the 2026-08-26 tailscale_key/atuin_key leak. Use \`sops -d --extract '[\"key\"]' <file>\` for one value, or \`sops -d <file> >/dev/null 2>&1; echo \$?\` to just test decrypt access. See .claude/skills/secrets-hygiene/SKILL.md."
        fi
    fi
fi

if [ -z "$reason" ] && grep -qE '\b(cat|bat|less|more|head|tail)\b[^|;&]*/run/secrets/' <<<"$command"; then
    reason="Reading a decrypted secret file directly prints its plaintext into the transcript. If you just need to confirm it exists/was written, use \`test -s <path>\`, \`stat <path>\`, or \`ls -la\` on its directory instead. See .claude/skills/secrets-hygiene/SKILL.md."
fi

if [ -n "$reason" ]; then
    jq -n --arg reason "$reason" '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "ask",
            permissionDecisionReason: $reason
        }
    }'
fi

exit 0
