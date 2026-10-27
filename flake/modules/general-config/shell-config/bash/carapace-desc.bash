# This file, flake/modules/general-config/shell-config/bash/carapace-desc.bash,
# adds descriptions to the Tab-completion menu for commands that carapace
# completes. Written 2026-08-22.
#
# Bash completion in three facts:
#   - `complete -F fn cmd` makes bash call `fn` when Tab is pressed after cmd.
#     For carapace, fn is _carapace_completer (`source <(carapace _carapace
#     bash)` in bash.nix defines it and registers it for ~every command
#     carapace has a spec for).
#   - Before the call bash sets COMP_WORDS (the words on the line so far) and
#     COMP_CWORD (index of the word being completed).
#   - fn answers by filling the array COMPREPLY with plain words. There is no
#     slot for a description.
#
# carapace does know descriptions; `carapace <cmd> export -- <words>` prints
# them as JSON, e.g. {"values":[{"value":"--amend","description":"amend
# previous commit",...}]}. The mechanism here is ble.sh "advice", a function
# that runs after another one. After _carapace_completer fills COMPREPLY, the
# advice below runs `export` for the same words, matches descriptions to the
# words in COMPREPLY, gives each word to ble.sh with its description, and
# empties COMPREPLY. The menu shows them because .blerc sets
# `bleopt complete_menu_style=desc`. ble.sh runs the original function itself
# for `after` advice; only `around` advice has to call it. The pattern is from
# ble.sh's contrib/integration/bash-completion.bash. cod-desc.bash does the
# same for cod, with a table in this repo instead of `export`.
#
# Every failure path (ble.sh not attached, no candidates, `export` empty or
# not JSON, no descriptions) leaves COMPREPLY alone, giving carapace's plain
# list as if this file did not exist.
#
# ~/.blerc loads this with `ble-import -d` (when idle), after bashrc has
# sourced carapace and carapace-completer-read-fix.bash, so the advice wraps
# the patched function.
#
# Trap: matching is by exact string. A candidate that differs from carapace's
# `.value` (say, a trailing `=` bash added) just gets no description, with no
# error. Each Tab costs one extra `carapace ... export` run, uncached.
# If descriptions don't show: run `carapace <cmd> export -- <words>` yourself
# and check `.values[].description` is non-empty and `.value` matches.
#
# Verified 2026-08-22: real _carapace_completer for `git commit --a` gave
# --ahead-behind --all --allow-empty --allow-empty-message --amend --author;
# this advice, with ble.sh's cand/yield, bleopt, test-limit and check-cancel
# replaced by logging stand-ins, re-yielded all 6 with `export` descriptions
# (`--amend` -> "amend previous commit") and emptied COMPREPLY.
# That check did not show that the advice never ran live (see the ADVICE_EXIT
# note in the function). Verified live 2026-10-26 (terminal-puppeteer, bash -i
# with ble.sh attached): `git commit --a` TAB TAB lists all 6 candidates with
# their descriptions, e.g. `--amend - amend previous commit`.

# The advice function. ble.sh calls it after _carapace_completer returns.
# Every `return 0` before the loop means "leave COMPREPLY alone".
function ble/contrib/carapace-desc/_carapace_completer.advice {
  # `${VAR-}` expands to VAR's value, or to nothing if VAR is unset (plain
  # `$VAR` on an unset variable is an error under `set -u`).
  # `[[ $x ]]` is true when $x is non-empty.
  [[ ${BLE_ATTACHED-} ]] || return 0   # ble.sh not attached: nothing to do
  # No check of ADVICE_EXIT (ble.sh's name for the wrapped function's exit
  # status) here, on purpose: _carapace_completer's last line is
  # `[[ "${COMPREPLY[*]}" == "" ]] && COMPREPLY=()`, so it returns 1 exactly
  # when it HAS candidates, and a `== 0` test would skip every useful case.
  # A failed completer leaves COMPREPLY empty, which this line catches.
  # `(( ... ))` evaluates arithmetic; it is true when the result is non-zero.
  ((${#COMPREPLY[@]}>=1)) || return 0  # `${#arr[@]}` is the length: no candidates
  # ble.sh's check that the candidate count is under its configured limit.
  ble/complete/source/test-limit "${#COMPREPLY[@]}" || return 0

  # The command being completed, e.g. `git`.
  local cmd=${COMP_WORDS[0]-}
  [[ $cmd ]] || return 0

  # Ask carapace for the same completion in JSON form, which includes
  # descriptions. `$(...)` captures the output; `command` skips any shell
  # function or alias named carapace; `2>/dev/null` discards error text.
  # `"${COMP_WORDS[@]:0:COMP_CWORD+1}"` is the words up to and including the
  # one being completed (a slice: start at 0, take COMP_CWORD+1 elements).
  local json
  json=$(command carapace "$cmd" export -- "${COMP_WORDS[@]:0:COMP_CWORD+1}" 2>/dev/null)
  [[ $json ]] || return 0

  # Turn the JSON into "value<TAB>description" lines with jq. Reading it:
  # `(.values // [])[]` iterates the "values" list (an empty list if the key
  # is missing); `select(...)` drops entries with no value; `@tsv` prints the
  # [value, description] pair as one tab-separated line. `<<<"$json"` feeds
  # the string to jq's standard input.
  local tsv
  tsv=$(command jq -r '
      (.values // [])[]
      | select(.value != null and .value != "")
      | [.value, (.description // "")] | @tsv
    ' <<<"$json" 2>/dev/null)
  [[ $tsv ]] || return 0

  # Load the lines into desc_of, an associative array (string keys):
  # desc_of[--amend]="amend previous commit". `local -A` makes it local to
  # this call, which is correct here: it is rebuilt on every Tab, because the
  # candidates differ every time. `IFS=$'\t'` makes `read` split on tabs only.
  local -A desc_of=()
  local value desc
  while IFS=$'\t' read -r value desc; do
    [[ $value ]] && desc_of[$value]=$desc
  done <<<"$tsv"
  ((${#desc_of[@]})) || return 0   # no descriptions at all: leave COMPREPLY

  # Hand every candidate to ble.sh, with a description where we have one.
  # `${!COMPREPLY[@]}` is the list of indices, not the values.
  local i cand has_desc=
  for i in "${!COMPREPLY[@]}"; do
    # Every N candidates (bleopt_complete_polling_cycle), ask ble.sh whether
    # the user has typed another key; if so, give up (148 is the status ble.sh
    # uses for "cancelled"). cand_iloop is a counter ble.sh declares as a
    # local in its calling function; bash functions can see their callers'
    # locals, so this one increments it. (If unset, arithmetic reads it as 0.)
    ((cand_iloop++%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && return 148
    cand=${COMPREPLY[i]}
    desc=${desc_of[$cand]-}
    # ble/complete/cand/yield adds one candidate to ble.sh's own list.
    # `word` is the candidate type (a plain word); the last argument is the
    # description the menu shows.
    if [[ $desc ]]; then
      ble/complete/cand/yield word "$cand" "$desc"
      has_desc=1
    else
      ble/complete/cand/yield word "$cand"
    fi
    # Remove the candidate from COMPREPLY now that ble.sh has it, so it is not
    # listed twice. `builtin unset` bypasses any alias or function named unset.
    builtin unset -v 'COMPREPLY[i]'
  done
  # `unset` leaves holes in the indices; this re-packs the (now empty) array.
  COMPREPLY=("${COMPREPLY[@]}")
  # Only switch the menu to the description layout if at least one candidate
  # actually has a description.
  [[ $has_desc ]] && bleopt complete_menu_style=desc
}

# Register the advice, if carapace's completer exists in this shell.
# `ble/function#advice after <function> <advice>` means: run <advice> after
# <function> returns.
function ble/contrib/carapace-desc/adjust {
  ble/is-function _carapace_completer || return 0
  ble/function#advice after _carapace_completer ble/contrib/carapace-desc/_carapace_completer.advice
}
ble/contrib/carapace-desc/adjust
