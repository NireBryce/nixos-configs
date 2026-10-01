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
#    `clean -f`, and a forced `checkout`/`switch` (-f, --discard-changes). What these destroy is
#    exactly what `git status --porcelain` lists, so the hook runs it in the
#    repo the command targets and decides on the answer, not the string:
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
#    The status runs with GIT_DIR/GIT_WORK_TREE/GIT_INDEX_FILE cleared and
#    --no-optional-locks: an inherited GIT_DIR silently retargets git
#    (lessons-learned §44), and a read-only check must not take the index
#    lock.
#
# 2. ASK + systemMessage -- force push, push --delete/:ref, push --mirror,
#    branch -D, filter-branch/filter-repo, stash drop/clear, restore onto the
#    worktree, worktree remove --force. Each has a routine legitimate use
#    (ship's post-merge `push --delete`, use-a-worktree's `worktree remove
#    --force`) and no status that settles it, so they stay "ask". The
#    systemMessage is what reaches the human transcript regardless of
#    permission mode, so under auto the warning is at least never silent.
#
# A deny outranks an ask when one command line trips both.
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

# classify <segment>: which tier-1 operation this git segment is, if any.
#   tracked   -- loses tracked changes (reset --hard, checkout ., forced
#                checkout/switch)
#   untracked -- loses untracked files (clean -f); untracked+ignored with -x
classify() {
    local seg=$1
    if grep -qE '\breset\b' <<<"$seg" && grep -qE -- '--ha(rd?)?\b' <<<"$seg"; then
        echo tracked
    elif grep -qE '\bcheckout\b[[:space:]]+(--[[:space:]]+)?\.([[:space:]]|$)' <<<"$seg"; then
        echo tracked
    elif grep -qE '\b(checkout|switch)\b' <<<"$seg" \
            && grep -qE -- "$force_flag_re|--discard-changes\b" <<<"$seg"; then
        echo tracked
    elif grep -qE '\bclean\b' <<<"$seg" && grep -qE -- "$force_flag_re" <<<"$seg"; then
        if grep -qE -- '(^|[[:space:]])-[a-zA-Z]*[xX][a-zA-Z]*([[:space:]]|$)' <<<"$seg"; then
            echo ignored
        else
            echo untracked
        fi
    fi
}

# Only look at commands that invoke git -- however it's spelled (`\git`,
# `/usr/bin/git`, `'git`, `g=git`) -- or carry a tier-1 verb even with no
# git word in sight (`$g reset --hard`).
git_word_re='(^|[^[:alnum:]_-])git([[:space:]]|$)'
if ! [[ $command =~ $git_word_re ]] && [ -z "$(classify "$command")" ]; then
    exit 0
fi

dirty_lines=""    # "in <repo>:" then "  <porcelain line>" per dirty path
count=0
unverified=""     # human-readable why, when a tier-1 op's repo can't be read
dir=$cwd

# A clean-tree verdict is only as good as the guard's idea of which repo the
# command acts on. The segment walk below models exactly two ways to move it:
# a bare `cd <path>` and a `git -C <path>` right after `git`. A blacklist of
# shapes it can't follow didn't converge -- PR #435's review found subshells,
# `bash -c`, `pushd`, `--git-dir`, `-c k=v -C d`, quoted cd paths, then (after
# those were fixed) a lone `&`, `if/then`, loops, `\git`, `/usr/bin/git`,
# `$g`, aliases, and `--har`, every one confirmed to allow `reset --hard`
# silently against a dirty repo while the payload cwd was clean.
#
# So it's a whitelist: when a tier-1 verb appears anywhere, a silent allow
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
if [ -n "$(classify "$command")" ]; then
    while IFS= read -r s; do
        s=$(sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' <<<"$s")
        [ -n "$s" ] || continue
        if ! [[ $s =~ $plain_cd || $s =~ $plain_git ]]; then
            unmodeled="'$s' is outside the plain 'cd <path>' / 'git [-C <path>] <subcommand> <args>' shapes the guard can follow"
            break
        fi
    done < <(awk '{ gsub(/&&|;/, "\n"); print }' <<<"$command")
fi
# Set up front, not when the walk reaches the op: a shape outside the
# grammar can hide the op from the walk entirely (`cd d & git reset --hard`
# is one `cd` segment to it). The walk still runs, so a dirty repo it can
# resolve still denies.
unverified=$unmodeled
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
    op=$(classify "$seg")
    [ -n "$op" ] || continue

    # Global options before the subcommand: only a lone `-C <path>` is modelled.
    if [[ $seg =~ (^|[[:space:]])git[[:space:]]+- ]] \
        && ! [[ $seg =~ (^|[[:space:]])git[[:space:]]+-C[[:space:]]+[^-[:space:]][^[:space:]]*[[:space:]]+[a-z] ]]; then
        unverified="'$seg' passes git options before the subcommand that the guard doesn't model"
        continue
    fi

    gdir=$dir
    if [[ $seg =~ (^|[[:space:]])git[[:space:]]+-C[[:space:]]+([^[:space:]]+) ]]; then
        gdir=$(resolve_dir "${BASH_REMATCH[2]}" "$gdir")
    fi
    if [ -z "$gdir" ]; then
        unverified="couldn't tell which repo '$seg' runs in (a variable, substitution or 'cd -' in the path)"
        continue
    fi
    case "$op" in
        tracked)   uflags=(-uno) ;;
        untracked) uflags=(-unormal) ;;
        ignored)   uflags=(-unormal --ignored) ;;
    esac
    if ! status=$(env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE \
            git -C "$gdir" --no-optional-locks status --porcelain "${uflags[@]}" 2>/dev/null); then
        unverified="'git status' failed in $gdir, so the tree's state is unknown"
        continue
    fi
    # clean leaves tracked changes alone: count only what it deletes.
    if [ "$op" != tracked ]; then
        status=$(grep -E '^(\?\?|!!) ' <<<"$status" || true)
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
if [ -z "$reason" ] && grep -qE '\bbranch\b' <<<"$command" \
    && grep -qE -- '(^|[[:space:]])-[a-zA-Z]*D[a-zA-Z]*([[:space:]]|$)' <<<"$command"; then
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
if [ -z "$reason" ] && grep -qE '\brestore([[:space:]]|$)' <<<"$command" \
    && { grep -qE -- '(^|[[:space:]])--worktree([[:space:]]|$)|(^|[[:space:]])-[wW]([[:space:]]|$)' <<<"$command" \
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
