#!/usr/bin/env bash
# PreToolUse hook (Bash matcher). Deterministic guard for the exact mistake
# documented in .agents/skills/secrets-hygiene/SKILL.md: on 2026-08-26 a bare
# `sops -d secrets.yaml` dumped the whole plaintext file -- tailscale_key and
# atuin_key included -- into the transcript, when only an exit-code check was
# needed. This is a pattern match, not a judgment call, so it runs every time
# rather than depending on the model remembering to be careful.
#
# What trips it:
#   1. a `sops` decrypt (`-d`, `--decrypt`, `sops decrypt`) whose own
#      pipeline stage has no `--extract` and doesn't send stdout to
#      /dev/null with nothing piped after it -- it prints the entire
#      decrypted file. `2>/dev/null` is stderr and doesn't count (how
#      2026-09-09 happened: three values out through `| grep ... 2>/dev/null`).
#   2. `sops exec-env` / `exec-file`.
#   3. anything touching the secrets directory other than a metadata
#      command (see the whitelist comment below).
# Each is DENIED, not asked (since 2026-09-29): there is always a narrower
# form that answers the same question (the reason text names them), and a
# deny reaches the model in every permission mode -- the model reads the
# reason and retries with the safe form. The earlier "ask" was a silent
# no-op under --permission-mode auto (issue #182's mechanism, found on
# git-guard), so in auto mode this guard used to do nothing at all. A rare
# genuine need for the whole file is the user's to run by hand.
# systemMessage travels with the deny so the human sees it in the transcript.
# Which keys exist -- the question that tempts the `sops -d | grep` shape --
# never needs decryption at all: `just read-sops-names` reads the committed
# ciphertext, where names are plaintext and values are ENC[...].
#
# No jq, no guard: without it the command can't be read, so the hook says so
# in a systemMessage (built by hand, no jq) on every call rather than
# allowing silently. The settings entry has no `|| true` for the same
# reason: a crash surfaces as a hook error instead of vanishing.
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
    cat >/dev/null
    printf '%s\n' '{"systemMessage":"secrets-guard-pretooluse: jq not on PATH, so this Bash command was NOT checked for sops -d / /run/secrets leaks. Install jq (packages-config/nix-utils/) to re-arm the guard."}'
    exit 0
fi

input=$(cat)
command=$(jq -r '.tool_input.command // empty' <<<"$input")

reason=""

# sops decrypt check, per pipeline stage: the decrypt flag, `--extract`, and
# the stdout-to-/dev/null exemption only count inside the stage that runs
# `sops`, so another command's `-d` (`grep -d`, `cut -d=`) on the same line
# neither trips nor exempts it. Quotes are stripped first, so `"-d"` counts.
# `N>&M` duplications are dropped and `&>` read as `>` before splitting, so
# the `&` in them isn't taken for a separator.
sops_scan=$(tr -d "'\"\\\\" <<<"$command" | sed -E 's/[0-9]*>&[0-9-]*/ /g; s/&>/>/g')
while IFS= read -r cmd; do
    grep -qE '(^|[^[:alnum:]_-])sops([[:space:]]|$)' <<<"$cmd" || continue
    IFS='|' read -r -a stages <<<"$cmd"
    last=$(( ${#stages[@]} - 1 ))
    for i in "${!stages[@]}"; do
        stage=${stages[$i]}
        grep -qE '(^|[^[:alnum:]_-])sops([[:space:]]|$)' <<<"$stage" || continue
        # A text tool's stage only mentions sops as an argument (`grep -d skip
        # -r sops .`) -- unless it carries a substitution, which can run it.
        # Tools that can run other commands (find -exec, awk, sed, xargs) are
        # deliberately not on this list.
        if [[ $stage =~ ^[[:space:]]*(grep|egrep|fgrep|rg|cut|sort|uniq|wc|tr|head|tail|ls|echo|printf)([[:space:]]|$) ]] \
            && ! grep -qE '\$\(|`' <<<"$stage"; then
            continue
        fi
        if grep -qE '(^|[^[:alnum:]_-])sops[[:space:]]+(.*[[:space:]])?exec-(env|file)([[:space:]]|$)' <<<"$stage"; then
            reason="'sops exec-env'/'exec-file' hand the decrypted values to a command. Use \`sops -d --extract '[\"key\"]' <file>\` for one value, or \`just read-sops-names\` for key names. A genuine need is the user's to run by hand. See .agents/skills/secrets-hygiene/SKILL.md."
            break 2
        fi
        grep -qE '(^|[[:space:]])(-d|--decrypt)([[:space:]=]|$)|(^|[^[:alnum:]_-])sops[[:space:]]+(.*[[:space:]])?decrypt([[:space:]]|$)' <<<"$stage" || continue
        grep -qE -- '(^|[[:space:]])--extract([[:space:]=]|$)' <<<"$stage" && continue
        # Stdout (fd1 or bare) to /dev/null, with nothing piped after it.
        if [ "$i" -eq "$last" ] && grep -qE '(^|[[:space:]])1?>[[:space:]]*/dev/null' <<<"$stage"; then
            continue
        fi
        reason="Bare 'sops -d' prints the WHOLE decrypted secrets.yaml into the transcript -- the 2026-08-26 tailscale_key/atuin_key leak, and again 2026-09-09 (three values) through a '2>/dev/null | grep'. Use \`sops -d --extract '[\"key\"]' <file>\` for one value, \`sops -d <file> >/dev/null 2>&1; echo \$?\` to just test decrypt access, or \`just read-sops-names\` for key names without decrypting. See .agents/skills/secrets-hygiene/SKILL.md."
        break 2
    done
done < <(awk '{ gsub(/&&|\|\||;|&/, "\n"); print }' <<<"$sops_scan")

# /run/secrets (and /run/secrets.d, where sops-nix keeps the real files):
# a whitelist, not a reader list. No task here needs a secret's contents --
# only whether it was deployed (exists, non-empty, owner, mode) -- so every
# segment that touches the path, or every segment at all when the payload cwd
# is already in there, must be a metadata command: ls, stat, test/[, or find
# without an action. Anything else denies, whatever the reader: `cd
# /run/secrets && cat foo` (PR #435 review), cut, cp, a tool not invented
# yet. The Read tool can't be seen from here at all; settings.json's
# permissions.deny covers it.
# Any non-name character ends the path: `/run/secrets;` and `/run/secrets.d`
# both match, `/run/secretsfoo` doesn't.
# Match against a normalized copy of the command (quotes and backslashes
# removed, repeated slashes and `.` segments collapsed), so equivalent
# spellings of the path are treated alike.
command_norm=$(tr -d "'\"\\\\" <<<"$command" | sed -E 's#/+#/#g; s#/(\./)+#/#g')
# A /run/ path containing a glob or `..` is also in scope: the guard
# doesn't resolve them, so it can't rule the secrets dir out.
secrets_path_re='/run/secrets([^[:alnum:]_-]|$)|/run/[^[:space:];&|]*([*?[]|\.\.)'
cwd=$(jq -r '.cwd // empty' <<<"$input")
in_secrets=false
[[ $cwd == /run/secrets || $cwd == /run/secrets/* || $cwd == /run/secrets.d* ]] && in_secrets=true
# A cd to /run itself plus any mention of secrets puts every segment in
# scope, since later relative paths are then under /run.
if grep -qE '(^|[;&|[:space:]])cd[[:space:]]+/run/?([;&|[:space:]]|$)' <<<"$command_norm" \
    && grep -qF secret <<<"$command_norm"; then
    in_secrets=true
fi
if [ -z "$reason" ] && { $in_secrets || grep -qE "$secrets_path_re" <<<"$command_norm"; }; then
    meta_re='^(ls|stat|test|\[|find)([[:space:]]|$)'
    while IFS= read -r seg; do
        seg=$(sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' <<<"$seg")
        [ -n "$seg" ] || continue
        $in_secrets || grep -qE "$secrets_path_re" <<<"$seg" || continue
        # Metadata only: no substitution or input redirect smuggling a read
        # in (`ls $(cat x)`), no find action that runs or prints contents.
        if [[ $seg =~ $meta_re ]] \
            && ! grep -qE '[$`<]|-(exec|execdir|ok|okdir|fprint|fprintf|fls|delete)\b' <<<"$seg"; then
            continue
        fi
        reason="'$seg' touches /run/secrets with something other than a metadata command. Nothing here needs a secret's contents: to confirm one was deployed, use \`test -s <path>\`, \`stat <path>\`, or \`ls -la /run/secrets/\`. See .agents/skills/secrets-hygiene/SKILL.md."
        break
    done < <(awk '{ gsub(/&&|\|\||;|\||&/, "\n"); print }' <<<"$command_norm")
fi

if [ -n "$reason" ]; then
    jq -n --arg reason "$reason" '{
        systemMessage: ("🔒 SECRETS GUARD (denied): " + $reason),
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: $reason
        }
    }'
fi

exit 0
