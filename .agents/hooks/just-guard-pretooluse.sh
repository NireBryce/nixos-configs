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
# Under ZCode (detected from the hook payload, below) this guard
# does nothing: its only job is to keep Claude Code's `Bash(just ...)` allow
# rules meaning this repo's recipes, and ZCode reads no allow rules. A deny
# there would block ordinary piped or redirected recipes this guard can't
# parse, with nothing to protect.
#
# Parsing: redirections are dropped first (they can't change which justfile
# runs, and the `&` in `2>&1` isn't a separator), then the command is split
# on `&& || ; | &`, `$(`, backticks and parentheses. In each segment, leading
# `VAR=value` assignments, shell keywords (then, do, {, !, ...) and exec
# wrappers (timeout, nice, nohup, stdbuf, xargs, env, command, builtin,
# exec, time, sudo) are skipped, options included; the segment runs `just`
# only if `just` is then its first word -- so prose that mentions just (a
# commit message, `grep just`) is not a `just` call. Fail closed: a segment
# still starting with a wrapper or keyword the parser couldn't strip, with
# `just` outside quotes in it, asks; with `cd`/`pushd`/`popd` in it, the
# directory becomes unknown. In a `just` call, every option before the
# recipe is checked (attached clusters like `-fx` and `--opt=value` too):
# those that pick a justfile, directory, shell or dotenv ask, and so does a
# recipe given as a path. Only `cd <plain-path>` moves the directory it
# tracks; any other cd/pushd/popd makes it unknown.
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
# Running under ZCode? Read from the payload, not the environment: ZCode
# builds the hook input as {...its own event, snake_case copies}, so its
# camelCase fields (hookEventName, transcriptPath) ride along; Claude Code's
# input is snake_case only. An inherited ZCODE_PROJECT_DIR (Claude Code
# started from a ZCode terminal) can't flip this.
zcode=$(jq -r 'if has("hookEventName") or has("transcriptPath") then "1" else empty end' <<<"$input")
[ -n "$zcode" ] && exit 0
command=$(jq -r '.tool_input.command // empty' <<<"$input")
cwd=$(jq -r '.cwd // empty' <<<"$input")
[ -n "$cwd" ] || cwd="${CLAUDE_PROJECT_DIR:-$PWD}"

just_word_re='(^|[^[:alnum:]_.-])just([[:space:]"'"'"']|$)'
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
# The segment's command, after leading assignments, shell keywords and
# exec wrappers (with their options and, for timeout/nice, their argument).
command_word() {
    local s=$1
    while :; do
        if [[ $s =~ ^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*([[:space:]]+(.*))?$ ]]; then
            s=${BASH_REMATCH[2]:-}
        elif [[ $s =~ ^(then|do|else|elif|if|while|until|\{|!)([[:space:]]+(.*))?$ ]]; then
            s=${BASH_REMATCH[3]:-}
        elif [[ $s =~ ^timeout(([[:space:]]+-[^[:space:]]+)*([[:space:]]+-[sk][[:space:]]+[^[:space:]]+)*)*[[:space:]]+[0-9.]+[smhd]?[[:space:]]+(.*)$ ]]; then
            s=${BASH_REMATCH[4]}
        elif [[ $s =~ ^nice(([[:space:]]+-n[[:space:]]*-?[0-9]+)|([[:space:]]+-[^[:space:]]+))*[[:space:]]+(.*)$ ]]; then
            s=${BASH_REMATCH[4]}
        elif [[ $s =~ ^(xargs|stdbuf|sudo|env|command|builtin|nohup|exec|time)(([[:space:]]+-[^[:space:]]+)*)[[:space:]]+(.*)$ ]]; then
            s=${BASH_REMATCH[4]}
        else
            break
        fi
    done
    printf '%s\n' "$s"
}

wrapper_re='^(then|do|else|elif|if|while|until|\{|!|timeout|nice|xargs|stdbuf|sudo|env|command|builtin|nohup|exec|time)([[:space:]]|$)'
unquoted_just_re='(^|[[:space:]])just([[:space:]]|$)'
cd_word_re='(^|[[:space:]])(cd|pushd|popd)([[:space:]]|$)'

# Quoted text removed, so a `just` inside a message isn't counted.
unquoted() {
    sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g" <<<"$1"
}

# Redirections can't change which justfile runs: drop them before splitting.
cleaned=$(sed -E 's/[0-9]*>&[0-9-]+//g; s/&>>?[[:space:]]*[^[:space:];&|()]+//g; s/[0-9]*>>?[[:space:]]*[^[:space:];&|()]+//g' <<<"$command")

dir=$cwd
while IFS= read -r seg; do
    seg=$(sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' <<<"$seg")
    [ -n "$seg" ] || continue
    orig=$seg
    seg=$(command_word "$seg")
    [ -n "$seg" ] || continue
    # A quoted command word is still the command: "just" / 'just'.
    seg=$(sed -E "s/^([\"'])just\\1([[:space:]]|\$)/just\\2/" <<<"$seg")
    if [[ $orig =~ $wrapper_re ]] && ! [[ $seg =~ ^(just|cd)([[:space:]]|$) ]]; then
        # Began with a wrapper or keyword the parser couldn't strip all the
        # way (an option taking a separate value, an unknown flag): judge the
        # whole original segment.
        bare=$(unquoted "$orig")
        if [[ $bare =~ $cd_word_re ]]; then
            dir=""
        fi
        if [[ $bare =~ $unquoted_just_re ]] && [ -z "$reason" ]; then
            reason="'$orig' runs just behind a wrapper or shell keyword this guard can't parse, so it can't tell which justfile it would use."
            break
        fi
        continue
    fi
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
    [[ $seg =~ ^just([[:space:]]|$) ]] || continue
    [ -z "$reason" ] || break
    picks=""
    # The long options that pick a justfile, directory, shell or dotenv are
    # checked anywhere in the call (no recipe takes them as arguments).
    if [[ $seg =~ [[:space:]](--justfile|--working-directory|--global-justfile|--shell|--shell-arg|--dotenv-[a-z-]+|--set)([[:space:]=]|$) ]]; then
        picks=1
    fi
    read -r -a words <<<"$seg"
    skip=""
    for w in "${words[@]:1}"; do
        [ -n "$picks" ] && break
        # The value of an option that takes a separate one.
        if [ -n "$skip" ]; then skip=""; continue; fi
        case $w in
            --color|--command-color|--chooser|--command|-c|--show|-s|--completions|--dump-format|--list-heading|--list-prefix|--tempdir|--timestamp-format|--alias-style|--list-submodules-prefix)
                skip=1; continue ;;
        esac
        case $w in
            --justfile|--justfile=*|--working-directory|--working-directory=*|--global-justfile|--shell|--shell=*|--shell-arg|--shell-arg=*|--dotenv-*|--set|--set=*)
                picks=1; break ;;
            --*) ;;
            -[A-Za-z]*)
                # a short-option cluster: -f, -d, -g anywhere in it picks one
                [[ ${w:1} == *[fdg]* ]] && { picks=1; break; } ;;
            *=*) ;;                      # a variable override (host=x)
            */*) picks=1; break ;;       # a recipe given as a path
            *) break ;;                  # the recipe: options end here
        esac
    done
    if [ -n "$picks" ]; then
        reason="'$seg' picks its justfile, directory, shell or dotenv explicitly, or names a recipe by path, so it may not run this repo's .justfile as-is."
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
done < <(awk '{ gsub(/&&|\|\||;|\||&|\$\(|`|\(|\)/, "\n"); print }' <<<"$cleaned")

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
