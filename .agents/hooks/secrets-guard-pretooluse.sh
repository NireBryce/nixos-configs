#!/usr/bin/env bash
# PreToolUse hook (Bash matcher). Deterministic guard for the exact mistake
# documented in .agents/skills/secrets-hygiene/SKILL.md: on 2026-08-26 a bare
# `sops -d secrets.yaml` dumped the whole plaintext file -- tailscale_key and
# atuin_key included -- into the transcript, when only an exit-code check was
# needed. This is a pattern match, not a judgment call, so it runs every time
# rather than depending on the model remembering to be careful.
#
# Three things trip it:
#   1. `sops -d`/`sops --decrypt` with no `--extract` and no stdout-to-
#      /dev/null redirect and no pipe -- prints the entire decrypted file.
#   2. the same command carrying `2>/dev/null` -- redirects only STDERR and
#      leaves stdout (the whole decrypted file) flowing into whatever comes
#      next; the original `/dev/null` exemption matched it anyway, which is
#      how 2026-09-09 happened (three values out via `sops -d ... |
#      grep ... 2>/dev/null`, two years--sorry, months--after the leak this
#      hook was written for).
#   3. `cat`/`bat`/`less`/`more`/`head`/`tail` reading a path under
#      /run/secrets/ -- prints a live decrypted secret's contents.
# Both ask for confirmation rather than hard-denying: there's a real
# alternative for each (see the reason text), but a rare legitimate case
# (e.g. actually needing the whole file) shouldn't be flatly impossible.
# Which keys exist -- the question that tempts the `sops -d | grep` shape --
# never needs decryption at all: `just read-sops-names` reads the committed
# ciphertext, where names are plaintext and values are ENC[...].
set -euo pipefail

input=$(cat)
command=$(jq -r '.tool_input.command // empty' <<<"$input")

reason=""

if grep -qE '\bsops\b' <<<"$command" && grep -qE '(\s|^)-d\b|--decrypt\b' <<<"$command"; then
    if ! grep -qE -- '--extract\b' <<<"$command"; then
        # Exemption needs BOTH: stdout (fd1 or bare) to /dev/null -- a
        # `2>`-prefixed redirect is stderr and does not count -- AND no
        # pipe anywhere in the command, since piped plaintext is the
        # leak shape itself.
        if ! { grep -qE '(^|[[:space:];&])1?>/dev/null' <<<"$command" \
                && ! grep -qF '|' <<<"$command"; }; then
            reason="Bare 'sops -d' prints the WHOLE decrypted secrets.yaml into the transcript -- the 2026-08-26 tailscale_key/atuin_key leak, and again 2026-09-09 (three values) through a '2>/dev/null | grep' this exemption used to miss. Use \`sops -d --extract '[\"key\"]' <file>\` for one value, \`sops -d <file> >/dev/null 2>&1; echo \$?\` to just test decrypt access, or \`just read-sops-names\` for key names without decrypting. See .agents/skills/secrets-hygiene/SKILL.md."
        fi
    fi
fi

if [ -z "$reason" ] && grep -qE '\b(cat|bat|less|more|head|tail)\b[^|;&]*/run/secrets/' <<<"$command"; then
    reason="Reading a decrypted secret file directly prints its plaintext into the transcript. If you just need to confirm it exists/was written, use \`test -s <path>\`, \`stat <path>\`, or \`ls -la\` on its directory instead. See .agents/skills/secrets-hygiene/SKILL.md."
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
