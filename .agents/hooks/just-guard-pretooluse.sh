#!/usr/bin/env bash
# PreToolUse hook (Bash matcher). Keeps `.agents/settings.json`'s
# `Bash(just <recipe>)` allow rules meaning "this repo's recipe".
#
# `just` uses the first justfile it finds walking up from the current
# directory, and an allow rule matches the command text, not the justfile
# behind it. This hook resolves which justfile each `just` would use and,
# when it isn't the repo's own `.justfile` -- or can't be told, or a flag
# picks one explicitly -- returns `ask`. Ask, not deny: it only withholds the
# pre-approval, so the dev-shells justfiles and the like still run after a
# prompt.
#
# Under ZCode (ZCODE_PROJECT_DIR set in the hook's environment) this guard
# does nothing: its only job is to keep Claude Code's `Bash(just ...)` allow
# rules meaning this repo's recipes, and ZCode reads no allow rules. A deny
# there would block ordinary piped or redirected recipes this guard can't
# parse, with nothing to protect.
#
# Same parse limits as git-guard's whitelist: only `cd <plain-path>` moves the
# directory it tracks, and any other segment shape that mentions `just` asks.
# Any JUST_* variable in the hook's environment (JUST_JUSTFILE,
# JUST_WORKING_DIRECTORY, JUST_DOTENV_*, JUST_SHELL, ...) can change which
# justfile runs or how, and the command inherits it, so every `just` asks
# then -- the same rule as git-guard's for an inherited GIT_DIR. The one git
# call runs with -c core.fsmonitor=false, so the check runs no program the
# repo's config names.
# Fixture tests: flake/scripts/test_guards.py.
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
    cat >/dev/null
    printf '%s\n' '{"systemMessage":"just-guard: jq not on PATH, so this Bash command was NOT checked for a foreign justfile. Install jq (packages-config/nix-utils/) to re-arm the guard."}'
    exit 0
fi

input=$(cat)
[ -n "${ZCODE_PROJECT_DIR:-}" ] && exit 0
command=$(jq -r '.tool_input.command // empty' <<<"$input")
cwd=$(jq -r '.cwd // empty' <<<"$input")
[ -n "$cwd" ] || cwd="${CLAUDE_PROJECT_DIR:-$PWD}"

just_word_re='(^|[^[:alnum:]_.-])just([[:space:]]|$)'
[[ $command =~ $just_word_re ]] || exit 0

plain_word='[A-Za-z0-9_./:@=+,~^%-]+'
plain_cd="^cd[[:space:]]+(${plain_word})\$"

# The justfile `just` would pick from <dir>: nearest ancestor holding a file
# named justfile (any case) or .justfile.
nearest_justfile() {
    local d=$1 f
    while :; do
        for f in "$d"/.justfile "$d"/[Jj][Uu][Ss][Tt][Ff][Ii][Ll][Ee]; do
            [ -f "$f" ] && { realpath "$f"; return 0; }
        done
        [ "$d" = / ] && return 0
        d=$(dirname "$d")
    done
}

# Is <file> the root .justfile of a checkout of this repo (main or worktree)?
is_repo_justfile() {
    local f=$1 top
    top=$(env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE \
              git -c core.fsmonitor=false -C "$(dirname "$f")" \
              rev-parse --show-toplevel 2>/dev/null) || return 1
    [ "$f" = "$(realpath "$top/.justfile")" ] \
        && [ -f "$top/.agents/hooks/just-guard-pretooluse.sh" ]
}

reason=""
just_env=$(compgen -e | grep '^JUST_' | paste -sd, - || true)
if [ -n "$just_env" ]; then
    reason="the hook's environment sets $just_env, which the command inherits and which can change the justfile just uses or how it runs it, so the guard can't tell it is this repo's .justfile."
fi
dir=$cwd
while IFS= read -r seg; do
    seg=$(sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' <<<"$seg")
    [ -n "$seg" ] || continue
    if [[ $seg =~ $plain_cd ]]; then
        p=${BASH_REMATCH[1]}
        case "$p" in
            /*) dir=$p ;;
            '~') dir=$HOME ;;
            '~/'*) dir=$HOME/${p#\~/} ;;
            *) dir=$dir/$p ;;
        esac
        continue
    fi
    if [[ $seg =~ ^(cd|pushd|popd)([[:space:]]|$) ]]; then
        # A directory change it can't read: later `just` runs somewhere
        # unknown.
        dir=""
        continue
    fi
    [[ $seg =~ $just_word_re ]] || continue
    [ -z "$reason" ] || break
    if ! [[ $seg =~ ^just([[:space:]]+${plain_word})*$ ]]; then
        reason="'$seg' runs just in a shape this guard can't follow, so it can't tell which justfile it would use."
        break
    fi
    if [[ $seg =~ (^|[[:space:]])(-f|--justfile|-d|--working-directory|-g|--global-justfile)([[:space:]=]|$) ]]; then
        reason="'$seg' picks its justfile explicitly, so it may not be this repo's .justfile."
        break
    fi
    if [ ! -d "$dir" ]; then
        reason="'$seg' would run from ${dir:-a directory a cd before it left unreadable}, which the guard can't resolve."
        break
    fi
    jf=$(nearest_justfile "$(realpath "$dir")")
    if [ -z "$jf" ] || ! is_repo_justfile "$jf"; then
        reason="'$seg' would run ${jf:-no justfile} (found walking up from $dir), not this repo's .justfile -- its recipes are not the ones .agents/settings.json pre-approves."
        break
    fi
done < <(awk '{ gsub(/&&|\|\||;|\||&/, "\n"); print }' <<<"$command")

if [ -n "$reason" ]; then
    decision="ask"
    jq -n --arg reason "$reason" --arg decision "$decision" '{
        systemMessage: ("⚠️  JUST GUARD: " + $reason),
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: $decision,
            permissionDecisionReason: $reason,
            additionalContext: $reason
        }
    }'
fi
exit 0
