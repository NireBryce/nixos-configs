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
# safe forms). Each path is made absolute (against the payload cwd) and
# normalized -- symlinks resolved with `realpath -m` where it exists,
# otherwise `//`, `.` and `..` collapsed lexically -- before matching, so
# equivalent spellings of the tree are treated alike. Grep also denies a
# search rooted at `/` or `/run` (it would recurse into the tree), and a
# Glob or Grep pattern is checked as a path too. Still a matcher, not a
# boundary (.agents/rules/agent-config.md). Edit/Write are not this hook's
# tools; secrets-guard-posttooluse watches their output.
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
tool=$(jq -r '.tool_name // empty' <<<"$input")
cwd=$(jq -r '.cwd // empty' <<<"$input")
[ -n "$cwd" ] || cwd="${CLAUDE_PROJECT_DIR:-$PWD}"
# Read takes file_path; Grep and Glob take path (default: the cwd).
base=$(jq -r '.tool_input.file_path // .tool_input.path // empty' <<<"$input")
# Glob's pattern, Grep's glob filter.
pattern=$(jq -r 'if .tool_name == "Glob" then (.tool_input.pattern // "")
                 else (.tool_input.glob // "") end' <<<"$input")

# absolute <path>: against the cwd when relative.
absolute() {
    case $1 in
        '~') printf '%s\n' "$HOME" ;;
        '~/'*) printf '%s\n' "$HOME/${1#\~/}" ;;
        /*) printf '%s\n' "$1" ;;
        *) printf '%s\n' "$cwd/$1" ;;
    esac
}

# normalize <absolute-path>: symlinks resolved where `realpath -m` exists,
# then `//`, `.` and `..` collapsed (also the whole job without realpath).
normalize() {
    local p=$1 r seg out=()
    if r=$(realpath -m -- "$p" 2>/dev/null) && [ -n "$r" ]; then
        p=$r
    fi
    local IFS=/
    set -f    # split on `/` only; never glob a segment like `*`
    for seg in $p; do
        case $seg in
            ''|.) ;;
            ..) [ ${#out[@]} -gt 0 ] && unset 'out[${#out[@]}-1]' ;;
            *) out+=("$seg") ;;
        esac
    done
    set +f
    printf '/%s\n' "${out[*]+"${out[*]}"}"
}

in_tree() {
    case $1 in
        /run/secrets|/run/secrets/*|/run/secrets.d|/run/secrets.d/*) return 0 ;;
    esac
    return 1
}

deny=""
if [ -n "$base" ] || [ "$tool" = Grep ] || [ "$tool" = Glob ]; then
    target=$(normalize "$(absolute "${base:-.}")")
    if in_tree "$target"; then
        deny=1
    elif [ "$tool" = Grep ] && { [ "$target" = / ] || [ "$target" = /run ]; }; then
        deny=1
    elif [ -n "$pattern" ]; then
        # The pattern's literal prefix (up to its first glob character),
        # taken as a path under the target.
        literal=${pattern%%[\*\?\[\{]*}
        case $pattern in
            /*) joined=$literal ;;
            *) joined=$target/$literal ;;
        esac
        if in_tree "$(normalize "$joined")"; then
            deny=1
        elif { [ "$target" = / ] || [ "$target" = /run ]; } \
            && [[ $pattern == *secret* ]]; then
            deny=1
        fi
    fi
fi
[ -n "$deny" ] || exit 0

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
