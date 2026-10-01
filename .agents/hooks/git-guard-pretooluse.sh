#!/usr/bin/env bash
# PreToolUse hook (Bash matcher). Deterministic guard against destructive git
# actions -- ones that discard commits, working-tree changes, stashes, or
# branches with no straightforward undo. A mechanical backstop for AGENTS.md's
# "confirm first" stance on anything hard to reverse, not a replacement for
# judgment; it does not gate on branch name (that policy is skill `ship`'s).
#
# Two tiers, since 2026-09-29:
#
# 1. STATE-CHECKED -- `reset --hard`, `checkout .`/`checkout -- .`,
#    `clean -f`, a forced `checkout`/`switch` (-f, --discard-changes),
#    `checkout [<tree-ish>] [--] <paths>` (two or more words, a `--`, a
#    path-only flag like --ours, or a lone word that doesn't resolve as a
#    commit in the target repo), and `rm -f` without --cached. Each op is
#    recognised in git's subcommand position, not as a word anywhere in the
#    segment. What these
#    destroy is what `git status --porcelain` lists, so the hook runs it in
#    the repo the command targets and decides on the answer, not the string.
#    The path forms check only their named pathspecs when those are plain
#    words (the whole tree otherwise), so discarding one file isn't blocked
#    by an unrelated dirty one. --pathspec-from-file (either spelling)
#    makes the target the whole tree, and its value is never read as a
#    pathspec or tree-ish. Checking out of a tree-ish also counts untracked
#    and ignored files that tree-ish would overwrite:
#    clean tree -> allow silently (nothing to lose; this is the ship skill's
#    `reset --hard origin/experimental` recovery after `git branch <b>`);
#    dirty tree -> DENY, listing the dirty paths and telling the model to ask
#    the user. Deny, not ask, because an ask is a silent no-op under
#    --permission-mode auto -- how the 2026-09-06 uncommitted-edit loss
#    (issue #182) got past this hook -- while a deny reaches the model in
#    every mode. `clean` counts untracked files (plus ignored ones under -x/
#    -X), the others count tracked changes only (-uno), since that's what
#    each actually removes. Which repo: the payload's .cwd, moved by any
#    literal `cd <dir>` segment before the git one, then by `git -C <dir>`.
#    A dir that can't be resolved statically (`cd "$W"`, `cd -`), or a
#    status that fails, falls back to tier 2's ask -- unknown is not clean.
#    The status runs with GIT_DIR/GIT_WORK_TREE/GIT_INDEX_FILE cleared,
#    -c core.fsmonitor=false (every git call the hook makes does: the check
#    runs no program the repo's config names) and
#    --no-optional-locks: an inherited GIT_DIR silently retargets git
#    (lessons-learned §44), and a read-only check must not take the index
#    lock. The command itself still inherits them, so when any is set in the
#    hook's environment a clean verdict is unverified -> ask.
#
# 2. ASK + systemMessage -- force push, push --delete/:ref, push --mirror,
#    branch -D (or -d with -f), filter-branch/filter-repo, stash drop/clear,
#    restore onto the worktree (or from --pathspec-from-file), read-tree -u,
#    worktree remove --force, and `checkout -B`/`switch -C`/`branch -f`/a
#    forced `branch -M|-C` when the target branch already exists (or its
#    repo can't be read). Each has a routine legitimate use
#    (ship's post-merge `push --delete`, use-a-worktree's `worktree remove
#    --force`) and no status that settles it, so they stay "ask". The
#    systemMessage is what reaches the human transcript regardless of
#    permission mode, so under auto the warning is at least never silent.
#
# A deny outranks an ask when one command line trips both.
#
# Not gated: `stash` push/save (-u/-a included) -- it moves work into a stash
# rather than dropping it, and the drop/clear that would lose it asks.
# `checkout <one word>` when the word resolves as a commit in the target
# repo -- a branch switch carries local changes or refuses.
#
# Known limits: pattern-matching on the command string, not a git parser.
# The tier-1 (state-checked) ops fail safe -- anything outside a plain
# cd/git grammar asks rather than trusting the cwd (see the whitelist
# comment below). The tier-2 asks are plain patterns: shell variables and
# aliases aren't followed and an unanticipated option cluster can slip
# through. Extend the patterns rather than assuming every shape is covered. Fixture tests: flake/scripts/test_guards.py.
set -euo pipefail

# No jq: say so (JSON built by hand) instead of allowing silently -- the
# same fail-visible rule as secrets-guard-pretooluse.sh's header.
if ! command -v jq >/dev/null 2>&1; then
    cat >/dev/null
    printf '%s\n' '{"systemMessage":"git-guard: jq not on PATH, so this Bash command was NOT checked for destructive git actions. Install jq (packages-config/nix-utils/) to re-arm the guard."}'
    exit 0
fi

input=$(cat)
command=$(jq -r '.tool_input.command // empty' <<<"$input")
cwd=$(jq -r '.cwd // empty' <<<"$input")
[ -n "$cwd" ] || cwd="${CLAUDE_PROJECT_DIR:-$PWD}"

# A short-option cluster or long flag carrying -f/--force (e.g. -f, -uf,
# -fd, --force), but not the safe long forms that refuse to overwrite work
# they haven't seen.
force_flag_re='(^|[[:space:]])-[a-zA-Z]*f[a-zA-Z]*([[:space:]]|$)|(^|[[:space:]])--force([[:space:]]|$)'
safe_force_re='--force-with-lease|--force-if-includes'

# --- Tier 1: state-checked ----------------------------------------------

# resolve_dir <path-word> <base>: print an absolute dir, or nothing when it
# can't be known without running the shell (variables, substitutions, `-`).
resolve_dir() {
    local p=$1 base=$2
    p=${p%\"}; p=${p#\"}; p=${p%\'}; p=${p#\'}
    case "$p" in
        ''|-|*'$'*|*'`'*) return 0 ;;
        '~') p=$HOME ;;
        '~/'*) p=$HOME/${p#\~/} ;;
    esac
    case "$p" in
        /*) printf '%s\n' "$p" ;;
        *) [ -n "$base" ] && printf '%s\n' "$base/$p" ;;
    esac
    return 0
}

# sub_args <text> <subcommand>: for each `git [global opts] <subcommand>` in
# <text>, print the words after the subcommand up to the next shell
# separator, one invocation per line. The subcommand must sit in git's
# subcommand position, so a commit message mentioning it doesn't count.
sub_args() {
    local line i
    local -a w
    while IFS= read -r line; do
        read -ra w <<<"$line"
        for i in "${!w[@]}"; do
            if [ "${w[$i]}" = "$2" ]; then
                printf '%s\n' "${w[*]:i+1}"
                break
            fi
        done
    done < <(grep -oE "(^|[^[:alnum:]_-])git(([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+)|([[:space:]]+-[^[:space:]]+))*[[:space:]]+$2([[:space:]][^;&|()<>]*)?" <<<"$1" || true)
}

co_first=""; co_paths=(); co_whole=0; co_single=0; rm_paths=()

# parse_checkout <args>: succeed when `git checkout <args>` may write paths
# into the worktree (`checkout [<tree-ish>] [--] <paths>`), setting
#   co_first  -- a word that is the tree-ish if it resolves as one (else a path)
#   co_paths  -- the remaining pathspecs (empty: unknown, check the whole tree)
#   co_whole  -- 1 when --pathspec-from-file names the paths: the whole tree
#                is the target, and the option's value is neither a pathspec
#                nor a tree-ish
#   co_single -- 1 for a lone word with no `--`: a branch switch when it
#                resolves as a commit, a path discard otherwise (the caller
#                decides, in the target repo)
# -b/-B/--orphan take a start point, never paths.
parse_checkout() {
    local t dd=0 pathopt=0 skip=0
    local -a w pos=() after=()
    read -ra w <<<"$1"
    co_first=""; co_paths=(); co_whole=0; co_single=0
    for t in "${w[@]}"; do
        if [ "$skip" = 1 ]; then skip=0; continue; fi
        if [ "$dd" = 1 ]; then after+=("$t"); continue; fi
        case "$t" in
            --) dd=1 ;;
            -b|-B|--orphan|--orphan=*|-[a-zA-Z]*[bB]) return 1 ;;
            --pathspec-from-file) co_whole=1; skip=1 ;;
            --pathspec-from-file=*) co_whole=1 ;;
            --ours|--theirs|--conflict=*|-p|--patch) pathopt=1 ;;
            -*) ;;
            *) pos+=("$t") ;;
        esac
    done
    if [ "$co_whole" = 1 ]; then
        co_first=${pos[0]:-}
    elif [ "$dd" = 1 ] && [ "${#after[@]}" -gt 0 ]; then
        co_first=${pos[0]:-}
        co_paths=("${pos[@]:1}" "${after[@]}")
    elif [ "${#pos[@]}" -ge 2 ]; then
        co_first=${pos[0]}
        co_paths=("${pos[@]:1}")
    elif [ "$pathopt" = 1 ]; then
        co_paths=("${pos[@]}")
    elif [ "$dd" = 0 ] && [ "${#pos[@]}" = 1 ]; then
        co_single=1
        co_paths=("${pos[0]}")
    else
        return 1
    fi
    return 0
}

# parse_rm <args>: succeed when `git rm <args>` deletes worktree files it
# would otherwise refuse to (-f, without --cached or a dry run), setting
# rm_paths to the named pathspecs (empty: unknown, check the whole tree --
# always so under --pathspec-from-file, whose value is not a pathspec).
parse_rm() {
    local t dd=0 force=0 whole=0 skip=0
    local -a w
    read -ra w <<<"$1"
    rm_paths=()
    for t in "${w[@]}"; do
        if [ "$skip" = 1 ]; then skip=0; continue; fi
        if [ "$dd" = 1 ]; then rm_paths+=("$t"); continue; fi
        case "$t" in
            --) dd=1 ;;
            --cached|-n|--dry-run) return 1 ;;
            --force) force=1 ;;
            --pathspec-from-file) whole=1; skip=1 ;;
            --pathspec-from-file=*) whole=1 ;;
            --*) ;;
            -*f*) force=1 ;;
            -*) ;;
            *) rm_paths+=("$t") ;;
        esac
    done
    [ "$whole" = 0 ] || rm_paths=()
    [ "$force" = 1 ]
}

# branch_reset <text>: print the branch a command would force onto a new
# commit, if any: `checkout -B <b>`, `switch -C <b>` (--force-create),
# `branch -f <b> [<start>]` (--force), and the target of a forced rename or
# copy, `branch -M|-C [<old>] <new>` (or -m/-c with -f).
branch_reset() {
    local args t prev sub force move skip
    local -a w pos
    for sub in checkout switch; do
        while IFS= read -r args; do
            read -ra w <<<"$args"
            prev=""
            for t in "${w[@]}"; do
                case "$sub:$prev" in
                    checkout:-B|checkout:-[a-zA-Z]*B|switch:-C|switch:-[a-zA-Z]*C|switch:--force-create)
                        printf '%s\n' "$t"; return 0 ;;
                esac
                prev=$t
            done
        done < <(sub_args "$1" "$sub")
    done
    while IFS= read -r args; do
        read -ra w <<<"$args"
        force=0; move=0; skip=0; pos=()
        for t in "${w[@]}"; do
            if [ "$skip" = 1 ]; then skip=0; continue; fi
            case "$t" in
                --force) force=1 ;;
                --move|--copy) move=1 ;;
                -d|--delete) move=2 ;;
                -u|--set-upstream-to|--contains|--no-contains|--merged|--no-merged|--points-at|--sort|--format) skip=1 ;;
                --*) ;;
                -*)
                    case "$t" in *f*) force=1 ;; esac
                    case "$t" in *[MC]*) force=1; move=1 ;; *[mc]*) move=1 ;; esac
                    case "$t" in *[dD]*) move=2 ;; esac
                    ;;
                *) pos+=("$t") ;;
            esac
        done
        if [ "$force" = 1 ] && [ "$move" != 2 ] && [ "${#pos[@]}" -gt 0 ]; then
            if [ "$move" = 1 ]; then
                printf '%s\n' "${pos[${#pos[@]}-1]}"
            else
                printf '%s\n' "${pos[0]}"
            fi
            return 0
        fi
    done < <(sub_args "$1" branch)
}

# classify <segment> [loose]: which tier-1 operation this git segment is, if
# any, keyed on git's subcommand position (sub_args).
#   tracked   -- loses tracked changes (reset --hard, checkout ., forced
#                checkout/switch)
#   untracked -- loses untracked files (clean -f); untracked+ignored with -x
#   paths     -- overwrites named paths (checkout [<tree-ish>] [--] <paths>,
#                or a lone checkout word that may not be a commit)
#   rmpaths   -- deletes named paths even when modified (rm -f)
# With `loose`, a tier-1 verb and its flag anywhere in the text also count
# (as `loose`): that is the whole-command test that decides whether the
# whitelist walk runs, so a git spelled through a variable or alias still
# can't be allowed silently. The per-segment state check uses the strict
# form only.
classify() {
    local seg=$1 a
    while IFS= read -r a; do
        if [[ " $a " =~ [[:space:]]--ha(r|rd)?[[:space:]] ]]; then echo tracked; return; fi
    done < <(sub_args "$seg" reset)
    while IFS= read -r a; do
        if [[ $a =~ ^(--[[:space:]]+)?\.([[:space:]]|$) ]]; then echo tracked; return; fi
    done < <(sub_args "$seg" checkout)
    while IFS= read -r a; do
        if grep -qE -- "$force_flag_re|--discard-changes\b" <<<"$a"; then echo tracked; return; fi
    done < <(sub_args "$seg" checkout; sub_args "$seg" switch)
    while IFS= read -r a; do
        if grep -qE -- "$force_flag_re" <<<"$a"; then
            if grep -qE -- '(^|[[:space:]])-[a-zA-Z]*[xX][a-zA-Z]*([[:space:]]|$)' <<<"$a"; then
                echo ignored
            else
                echo untracked
            fi
            return
        fi
    done < <(sub_args "$seg" clean)
    while IFS= read -r a; do
        if parse_checkout "$a"; then echo paths; return; fi
    done < <(sub_args "$seg" checkout)
    while IFS= read -r a; do
        if parse_rm "$a"; then echo rmpaths; return; fi
    done < <(sub_args "$seg" rm)
    [ "${2:-}" = loose ] || return 0
    if { grep -qE '\breset\b' <<<"$seg" && grep -qE -- '--ha(rd?)?\b' <<<"$seg"; } \
        || grep -qE '\bcheckout\b[[:space:]]+(--[[:space:]]+)?\.([[:space:]]|$)' <<<"$seg" \
        || { grep -qE '\b(checkout|switch|clean|rm)\b' <<<"$seg" \
             && grep -qE -- "$force_flag_re|--discard-changes\b" <<<"$seg"; }; then
        echo loose
    fi
}

# Only look at commands that invoke git -- however it's spelled -- or carry
# a tier-1 verb even with no git word in sight.
git_word_re='(^|[^[:alnum:]_-])git([[:space:]]|$)'
if ! [[ $command =~ $git_word_re ]] && [ -z "$(classify "$command" loose)" ]; then
    exit 0
fi

dirty_lines=""    # "in <repo>:" then "  <porcelain line>" per dirty path
count=0
unverified=""     # human-readable why, when a tier-1 op's repo can't be read
dir=$cwd

# A clean-tree verdict is only as good as the guard's idea of which repo the
# command acts on. The segment walk below models exactly two ways to move it:
# a bare `cd <path>` and a `git -C <path>` right after `git`. Listing the
# shapes it can't follow never converged (#435), so it's a whitelist: when a tier-1 verb appears anywhere, a silent allow
# needs EVERY segment (split on && ; newline only) to be one of
#     cd <word>
#     git [-C <word>] <subcommand> <word>...
# with <word> free of quotes, $, backticks, globs, redirects and | & ( ) { }.
# Anything else makes the op unverified -> ask, as before the dirty-tree
# check existed. A dirty repo the walk CAN resolve still denies.
plain_word='[A-Za-z0-9_./:@=+,~^%-]+'
plain_cd="^cd[[:space:]]+${plain_word}\$"
plain_git="^git([[:space:]]+-C[[:space:]]+${plain_word})?[[:space:]]+[a-z][a-z-]*([[:space:]]+${plain_word})*\$"
unmodeled=""
tier1=$(classify "$command" loose)
resets=$(branch_reset "$command")
if [ -n "$tier1" ] || [ -n "$resets" ]; then
    while IFS= read -r s; do
        s=$(sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' <<<"$s")
        [ -n "$s" ] || continue
        if ! [[ $s =~ $plain_cd || $s =~ $plain_git ]]; then
            unmodeled="'$s' is outside the plain 'cd <path>' / 'git [-C <path>] <subcommand> <args>' shapes the guard can follow"
            break
        fi
    done < <(awk '{ gsub(/&&|;/, "\n"); print }' <<<"$command")
fi
# The status below runs with these cleared; the command itself inherits
# them, and git then acts on the repo they name, not the one checked.
inherited=""
for v in GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE; do
    if [ -n "${!v:-}" ]; then inherited+="${inherited:+, }$v"; fi
done
inherited_why=""
[ -z "$inherited" ] || inherited_why="runs with $inherited set in its environment, so git acts on the repo that names rather than the one checked"
# Set up front, not when the walk reaches the op: a shape outside the
# grammar can hide the op from the walk entirely. The walk still runs, so a
# dirty repo it can resolve still denies.
unverified=""
[ -z "$tier1" ] || unverified=${unmodeled:-$inherited_why}
# Every git call below runs with the inherited repo-selecting variables
# cleared and core.fsmonitor off, so the check never runs a program the
# repo's config names. status/rev-parse/ls-tree/show-ref run no hooks.
gitq=(env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE git -c core.fsmonitor=false)
branch_why=""     # tier-2 reason for checkout -B / switch -C / branch -f
plain_word_re="^${plain_word}\$"

# all_plain <word>...: every word is a plain literal, usable as a pathspec.
all_plain() {
    local p
    for p in "$@"; do [[ $p =~ $plain_word_re ]] || return 1; done
}

while IFS= read -r seg; do
    seg=$(sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' <<<"$seg")
    [ -n "$seg" ] || continue
    if [[ $seg =~ ^cd([[:space:]]+([^[:space:]]+))?[[:space:]]*$ ]]; then
        if [ -n "${BASH_REMATCH[2]:-}" ]; then
            dir=$(resolve_dir "${BASH_REMATCH[2]}" "$dir")
        else
            dir=$HOME
        fi
        continue
    fi
    if [[ $seg =~ ^cd([[:space:]]|$) ]]; then
        # A cd the regex above can't read (quoted path with a space, extra
        # args): every later segment's repo is unknown.
        dir=""
        continue
    fi
    [[ $seg =~ $git_word_re ]] || continue

    gdir=$dir
    if [[ $seg =~ (^|[[:space:]])git[[:space:]]+-C[[:space:]]+([^[:space:]]+) ]]; then
        gdir=$(resolve_dir "${BASH_REMATCH[2]}" "$gdir")
    fi

    # checkout -B / switch -C / branch -f: asks when the branch already exists, or when
    # the repo it would be looked up in isn't known.
    b=$(branch_reset "$seg")
    if [ -n "$b" ] && [ -z "$branch_why" ]; then
        if [ -n "$unmodeled$inherited_why" ] || [ -z "$gdir" ] || ! [[ $b =~ $plain_word_re ]]; then
            branch_why="the guard can't tell whether branch '$b' already exists"
        else
            rc=0
            "${gitq[@]}" -C "$gdir" show-ref --verify -q "refs/heads/$b" 2>/dev/null || rc=$?
            if [ "$rc" = 0 ]; then
                branch_why="branch '$b' already exists"
            elif [ "$rc" != 1 ]; then
                branch_why="the guard couldn't look up branch '$b' in $gdir"
            fi
        fi
    fi

    op=$(classify "$seg")
    [ -n "$op" ] || continue

    # Global options before the subcommand: only a lone `-C <path>` is modelled.
    if [[ $seg =~ (^|[[:space:]])git[[:space:]]+- ]] \
        && ! [[ $seg =~ (^|[[:space:]])git[[:space:]]+-C[[:space:]]+[^-[:space:]][^[:space:]]*[[:space:]]+[a-z] ]]; then
        unverified="'$seg' passes git options before the subcommand that the guard doesn't model"
        continue
    fi
    if [ -z "$gdir" ]; then
        unverified="couldn't tell which repo '$seg' runs in (a variable, substitution or 'cd -' in the path)"
        continue
    fi
    g=("${gitq[@]}" -C "$gdir" --no-optional-locks)

    # Which changes the op destroys, scoped to its pathspecs when they are
    # plain words (otherwise the whole tree).
    treeish=""
    pathspec=()
    case "$op" in
        tracked)   uflags=(-uno) ;;
        untracked) uflags=(-unormal) ;;
        ignored)   uflags=(-unormal --ignored) ;;
        paths)
            uflags=(-uno)
            parse_checkout "$(sub_args "$seg" checkout | head -n 1)" || true
            # A lone word that resolves as a commit is a branch switch, which
            # carries local changes or refuses; otherwise git reads it as a
            # pathspec and discards its changes.
            if [ "$co_single" = 1 ] \
                && "${g[@]}" rev-parse -q --verify "${co_paths[0]}^{commit}" >/dev/null 2>&1; then
                continue
            fi
            p=("${co_paths[@]}")
            if [ -n "$co_first" ]; then
                if "${g[@]}" rev-parse -q --verify "$co_first^{tree}" >/dev/null 2>&1; then
                    treeish=$co_first
                else
                    p=("$co_first" "${p[@]}")
                fi
            fi
            if [ "$co_whole" = 0 ] && [ "${#p[@]}" -gt 0 ] && all_plain "${p[@]}"; then
                pathspec=(-- "${p[@]}")
            fi
            ;;
        rmpaths)
            uflags=(-uno)
            parse_rm "$(sub_args "$seg" rm | head -n 1)" || true
            if [ "${#rm_paths[@]}" -gt 0 ] && all_plain "${rm_paths[@]}"; then
                pathspec=(-- "${rm_paths[@]}")
            fi
            ;;
    esac
    if ! status=$("${g[@]}" status --porcelain "${uflags[@]}" "${pathspec[@]}" 2>/dev/null); then
        unverified="'git status' failed in $gdir, so the tree's state is unknown"
        continue
    fi
    # clean leaves tracked changes alone: count only what it deletes.
    if [ "$op" = untracked ] || [ "$op" = ignored ]; then
        status=$(grep -E '^(\?\?|!!) ' <<<"$status" || true)
    fi
    # Checking paths out of a tree-ish also overwrites untracked and ignored
    # files that exist in that tree-ish.
    if [ -n "$treeish" ]; then
        if ! untracked=$("${g[@]}" status --porcelain -uall --ignored=traditional "${pathspec[@]}" 2>/dev/null) \
            || ! intree=$("${g[@]}" ls-tree -r --name-only --full-tree "$treeish" 2>/dev/null); then
            unverified="'git status' failed in $gdir, so the tree's state is unknown"
            continue
        fi
        hit=$(sed -nE 's/^(\?\?|!!) //p' <<<"$untracked" | grep -Fx -f <(printf '%s\n' "$intree") || true)
        if [ -n "$hit" ]; then
            hit=$(grep -Fx -f <(sed 's/^/?? /' <<<"$hit"; sed 's/^/!! /' <<<"$hit") <<<"$untracked" || true)
            status+="${status:+$'\n'}$hit"
        fi
    fi
    if [ -n "$status" ]; then
        count=$((count + $(grep -c . <<<"$status")))
        dirty_lines+="in $gdir:"$'\n'$(sed 's/^/  /' <<<"$status")$'\n'
    fi
done < <(awk '{ gsub(/&&|\|\||;|\|/, "\n"); print }' <<<"$command")

if [ "$count" -gt 0 ]; then
    listing=$(grep . <<<"$dirty_lines" | head -n 21)
    if [ "$count" -gt 20 ]; then listing+=$'\n'"  ... ($count dirty paths in all)"; fi
    reason="This git command would discard uncommitted work -- the working tree is dirty ($count path(s), from git status --porcelain):
$listing
Denied rather than asked: an ask is a silent no-op under auto permission mode (issue #182). Do not retry around this. Ask the user whether these changes can be lost -- they may be another session's work in a shared checkout -- or commit/stash them first."
    jq -n --arg reason "$reason" --arg count "$count" '{
        systemMessage: ("⛔ DESTRUCTIVE GIT COMMAND DENIED: dirty tree (" + $count + " path(s)); the agent was told to ask you first."),
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: $reason
        }
    }'
    exit 0
fi

# --- Tier 2: ask ----------------------------------------------------------

reason=""
if [ -n "$unverified" ]; then
    reason="This git command discards uncommitted work if the tree is dirty, and the guard $unverified. Run 'git status --short' in that repo first; if anything is listed that isn't yours to drop, stop and ask the user."
fi

# git checkout -B / switch -C / branch -f (or a forced branch rename/copy)
# onto an existing branch: moves its pointer, leaving commits only on the old
# tip reachable from the reflog alone.
if [ -z "$reason" ] && [ -n "$branch_why" ]; then
    reason="This resets a branch pointer ('checkout -B' / 'switch -C' / 'branch -f' / 'branch -M|-C') and $branch_why. Commits only on its current tip stop being reachable from any branch. Confirm they are safe to drop, or create a new branch instead."
fi

# git read-tree -u (with -m or --reset): writes the read tree into the
# working tree, overwriting local changes to the paths it updates.
if [ -z "$reason" ]; then
    while IFS= read -r a; do
        if [[ " $a " =~ [[:space:]](-[a-zA-Z]*u[a-zA-Z]*|--update)[[:space:]] ]]; then
            reason="'git read-tree -u' writes the tree it reads into the working tree, overwriting uncommitted changes to the paths it updates. Confirm nothing uncommitted is about to be lost."
            break
        fi
    done < <(sub_args "$command" read-tree)
fi

# git push --force / -f
if [ -z "$reason" ] && grep -qE '\bpush\b' <<<"$command" \
    && grep -qE -- "$force_flag_re" <<<"$command" \
    && ! grep -qE -- "$safe_force_re" <<<"$command"; then
    reason="This looks like a force push (--force/-f, not --force-with-lease) -- it can overwrite remote history and silently discard someone else's commits. Confirm this is intended, or use --force-with-lease so it fails instead of overwriting unseen work."
fi

# git push --delete / -d <ref>, or the :branch colon-refspec deletion form
if [ -z "$reason" ] && grep -qE '\bpush\b' <<<"$command" \
    && grep -qE -- '--delete\b|(^|[[:space:]])-d([[:space:]]|$)|[[:space:]]:[A-Za-z]' <<<"$command"; then
    reason="This looks like it deletes a remote branch or tag. Confirm the ref is actually meant to go -- this is the routine post-merge cleanup step in the ship skill, but is otherwise hard to undo once someone else has fetched it."
fi

# git branch -D (force delete, unlike the plain -d the ship skill uses for
# its own already-merged post-PR cleanup)
# -d/--delete together with -f/--force is the same force delete.
branch_force_delete() {
    local a
    while IFS= read -r a; do
        a=" $a "
        if [[ $a =~ [[:space:]](-[a-zA-Z]*d[a-zA-Z]*|--delete)[[:space:]] ]] \
            && [[ $a =~ [[:space:]](-[a-zA-Z]*f[a-zA-Z]*|--force)[[:space:]] ]]; then
            return 0
        fi
    done < <(sub_args "$1" branch)
    return 1
}
if [ -z "$reason" ] && { { grep -qE '\bbranch\b' <<<"$command" \
    && grep -qE -- '(^|[[:space:]])-[a-zA-Z]*D[a-zA-Z]*([[:space:]]|$)' <<<"$command"; } \
    || branch_force_delete "$command"; }; then
    reason="'-D' force-deletes a branch even if it has commits not merged anywhere else -- unlike the plain '-d' the ship skill uses for its already-merged post-PR cleanup. Confirm the branch's commits are actually safe to lose."
fi

# history rewriting
if [ -z "$reason" ] && grep -qE '\b(filter-branch|filter-repo)\b' <<<"$command"; then
    reason="This rewrites repository history wholesale. Confirm this is really intended -- it changes commit hashes for everything downstream and can't be undone once pushed."
fi

# git stash drop / clear
if [ -z "$reason" ] && grep -qE '\bstash\b' <<<"$command" && grep -qE '\b(drop|clear)\b' <<<"$command"; then
    reason="This permanently discards stashed changes with no undo. Confirm the stash isn't still needed."
fi

# git restore onto the working tree -- the modern spelling of `checkout -- .`,
# which tier 1 state-checks; restore stays an ask (--staged . only unstages). A bare-dot target asks regardless of the other
# flags on it, including --staged: telling `--staged .` (which only unstages)
# apart from the destructive shapes needs segment-scoped parsing this hook
# deliberately doesn't do -- a whole-command `--staged` carve-out leaked
# across `&&` and suppressed the ask for `git restore .` after a
# `--staged` earlier in the same line (found in review, 2026-09-29), and
# over-asking is the safe direction for an ask. --worktree/-w asks even on
# a single file, for symmetry with the checkout force gate.
# `restore` is anchored to a following space/EOL, not `\brestore\b`, so a
# path like .../restore-root/ doesn't read as the verb.
# --pathspec-from-file makes the target every path the file lists, so it is
# treated as the whole tree, like a dot.
if [ -z "$reason" ] && grep -qE '\brestore([[:space:]]|$)' <<<"$command" \
    && { grep -qE -- '(^|[[:space:]])--worktree([[:space:]]|$)|(^|[[:space:]])-[wW]([[:space:]]|$)|(^|[[:space:]])--pathspec-from-file([[:space:]=]|$)' <<<"$command" \
         || grep -qE '\brestore([[:space:]]([^;|&]*[[:space:]])?)\.([[:space:]]|$)' <<<"$command"; }; then
    reason="'git restore' onto the working tree discards uncommitted changes with no undo -- the modern spelling of 'git checkout -- .', which this hook also catches. Confirm nothing uncommitted is about to be lost ('--staged .' only unstages but trips too; '--staged <file>' without a dot does not trip)."
fi

# git worktree remove --force: deletes a worktree even when it holds
# uncommitted or unpushed work. Plain `remove` refuses those -- which is what
# makes the forced form worth a pause, and why only it is matched. This is
# also `use-a-worktree`'s documented cleanup step, so expect it when tearing
# down a finished worktree.
if [ -z "$reason" ] && grep -qE '\bworktree([[:space:]]|$)' <<<"$command" \
    && grep -qE '\bremove([[:space:]]|$)' <<<"$command" \
    && grep -qE -- "$force_flag_re" <<<"$command"; then
    reason="'git worktree remove --force' deletes a worktree even when it holds uncommitted or unpushed changes -- plain 'remove' refuses those. Confirm the worktree has nothing unsaved (this is also the use-a-worktree skill's documented cleanup step, so it's expected then)."
fi

# git push --mirror: makes the remote exactly match local, deleting every
# remote branch and tag that does not exist locally -- far wider than
# --force, which only rewrites the refs actually named.
if [ -z "$reason" ] && grep -qE '\bpush\b' <<<"$command" \
    && grep -qE -- '(^|[[:space:]])--mirror([[:space:]]|$)' <<<"$command"; then
    reason="'git push --mirror' makes the remote exactly match local -- it deletes every remote branch and tag that does not exist locally, not just the refs named. Confirm that is really intended."
fi

if [ -n "$reason" ]; then
    jq -n --arg reason "$reason" '{
        systemMessage: ("⚠️  DESTRUCTIVE GIT COMMAND: " + $reason),
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "ask",
            permissionDecisionReason: $reason
        }
    }'
fi

exit 0
