#!/usr/bin/env bash
# PostToolUse hook (Bash matcher). Safety net for secrets-hygiene: if a
# secret-shaped value shows up in a Bash tool's output anyway -- despite the
# PreToolUse guard (secrets-guard-pretooluse.sh), or from a command that
# guard doesn't cover -- flag it immediately rather than relying on the model
# noticing on its own before quoting the result. See
# .claude/skills/secrets-hygiene/SKILL.md and the 2026-08-26 incident it
# documents (tailscale_key/atuin_key leaked via a bare `sops -d`).
#
# Deliberately narrow: matches known secret *shapes* (a Tailscale auth key,
# an age secret key, a private key block) and this repo's own sensitive
# secrets.yaml key names paired with a bare (non-ENC[...]) value. Does NOT
# flag the encrypted secrets.yaml blob itself (ENC[...] is ciphertext, safe
# to show -- CLAUDE.md's Safety section), and does not flag public-key-shaped
# or device-ID-shaped entries (ssh-*, syncthing-*), which aren't secrets.
set -euo pipefail

input=$(cat)
# Extract stdout/stderr as RAW text, not `tostring` on the whole object --
# tostring re-serializes an object to compact JSON, which turns real
# newlines inside .stdout into literal two-character `\n` escapes and glues
# the rest of the JSON structure onto that same "line". That silently broke
# every newline-sensitive check below (found live, 2026-08-26: a plain list
# of secrets.yaml key names with no values at all was flagged, because the
# JSON-escaped remainder of the blob became "content after the key name").
text=$(jq -r '
    if (.tool_response | type) == "object" then
        [(.tool_response.stdout // ""), (.tool_response.stderr // "")] | join("\n")
    elif (.tool_response | type) == "string" then
        .tool_response
    else
        empty
    end
' <<<"$input" 2>/dev/null || true)

hit=""
grep -qE 'tskey-[A-Za-z0-9_-]+' <<<"$text" && hit="a Tailscale auth key (tskey-...)"
[ -z "$hit" ] && grep -qE 'AGE-SECRET-KEY-[A-Z0-9]+' <<<"$text" && hit="an age secret key (AGE-SECRET-KEY-...)"
[ -z "$hit" ] && grep -qE -- '-----BEGIN (OPENSSH|RSA|EC|DSA) PRIVATE KEY-----' <<<"$text" && hit="a private key block"
[ -z "$hit" ] && grep -qP '\b(tailscale_key|atuin_key):[ \t]*+(?!ENC\[).{15,}' <<<"$text" && hit="a bare tailscale_key/atuin_key value (not ENC[...])"

if [ -n "$hit" ]; then
    jq -n --arg hit "$hit" '{
        decision: "block",
        reason: ("This tool output looks like it contains " + $hit + " in plaintext. STOP before quoting or summarizing it in your reply: refer to it by name only, tell the user it leaked, and recommend rotation rather than continuing the original task as if nothing happened. See .claude/skills/secrets-hygiene/SKILL.md."),
        hookSpecificOutput: {
            hookEventName: "PostToolUse",
            additionalContext: ("secrets-hygiene guard: possible plaintext secret (" + $hit + ") detected in this tool output. Do not repeat it in your reply; name it only, and flag rotation.")
        }
    }'
fi

exit 0
