# This file, flake/modules/general-config/shell-config/bash/cod-desc.bash,
# adds descriptions to the Tab-completion menu for commands that cod
# completes. Written 2026-09-25.
#
# Bash completion in three facts:
#   - `complete -F fn cmd` makes bash call `fn` when Tab is pressed after cmd.
#     For cod, fn is __cod_complete_bash (defined by `cod init $$ bash`,
#     run from bash.nix).
#   - Before the call bash sets COMP_WORDS (the words on the line so far) and
#     COMP_CWORD (index of the word being completed).
#   - fn answers by filling the array COMPREPLY with plain words. There is no
#     slot for a description, and cod's database has no description column
#     either (checked against dim-an/cod v0.1.0).
#
# So the descriptions live in this repo: cod-desc.tsv, next to this file, one
# `command<TAB>candidate<TAB>description` per line. blesh.nix puts it in the
# Nix store and sets NIRE_COD_DESC_TSV (a plain, unexported shell variable in
# ~/.blerc) to its path. Add rows with `just cod-desc draft <cmd>`; workflow
# in skill cod-completions, background in wiki/config-structure/categories/shell-config/
# cod-desc.md.
#
# The mechanism is ble.sh "advice": a function that runs after another one.
# After __cod_complete_bash fills COMPREPLY, the advice below looks each word
# up in the table, gives each word to ble.sh together with its description,
# and empties COMPREPLY. The menu shows descriptions because .blerc sets
# `bleopt complete_menu_style=desc`. If the table has no row for any
# candidate, COMPREPLY is left alone so ble.sh can still attach man-page
# descriptions. carapace-desc.bash does the same for carapace, using the
# pattern from ble.sh's own contrib/integration/bash-completion.bash.
#
# cod offers value-taking flags as `--opt=`. Table rows are keyed without the
# `=`, so the lookup tries the candidate as given, then without a trailing `=`.
#
# This is loaded with `ble-import -d` (run when idle) because .blerc is read
# before bash.nix runs `cod init`; at read time __cod_complete_bash does not
# exist yet. The is-function check in `adjust` makes this a no-op where cod is
# absent (the darwin hosts).
#
# If descriptions don't show: `complete -p <cmd>` must name
# __cod_complete_bash (cod registers per learned command), NIRE_COD_DESC_TSV
# must name an existing file, and the command needs rows in the table.
#
# Verified 2026-09-25 with ble.sh's cand/yield, test-limit and check-cancel
# replaced by stand-ins that log their arguments: sops candidates came back
# with the table's descriptions, `--value-stdin=` through the stripped lookup,
# a command with no rows untouched.
# Verified live 2026-10-26 (terminal-puppeteer, bash -i with ble.sh attached,
# this file and cod-desc.tsv loaded from the working tree): `sops --de` TAB
# TAB showed `--decrypt - Decrypt a file and output the result to stdout`,
# and `sops --va` showed `--value-stdin` and `--value-file` with their
# descriptions. The same keystrokes against the previous generation (plain
# `declare -A`) printed `arithmetic syntax error` and offered nothing.

# The advice function. ble.sh calls it after __cod_complete_bash returns.
# Every `return 0` in the first few lines means "leave COMPREPLY alone".
function ble/contrib/cod-desc/_cod_complete_bash.advice {
  # `${VAR-}` expands to VAR's value, or to nothing if VAR is unset. Plain
  # `$VAR` on an unset variable would be an error under `set -u`.
  # `[[ $x ]]` is true when $x is non-empty.
  [[ ${BLE_ATTACHED-} ]] || return 0   # ble.sh not attached: nothing to do
  # ADVICE_EXIT is set by ble.sh to the exit status of the function we wrap.
  # `(( ... ))` evaluates arithmetic; it is true when the result is non-zero.
  ((ADVICE_EXIT==0)) || return 0       # the real completer failed
  ((${#COMPREPLY[@]}>=1)) || return 0  # `${#arr[@]}` is the length: no candidates
  # -s: file exists and is not empty.
  [[ ${NIRE_COD_DESC_TSV-} && -s "$NIRE_COD_DESC_TSV" ]] || return 0
  # ble.sh's check that the candidate count is under its configured limit.
  ble/complete/source/test-limit "${#COMPREPLY[@]}" || return 0

  # The command being completed, e.g. `sops`. `${COMP_WORDS[0]-}` is the
  # first word on the line. `${cmd##*/}` deletes the longest prefix matching
  # `*/`, so `/usr/bin/sops` becomes `sops`: the table is keyed by bare name.
  local cmd=${COMP_WORDS[0]-}
  [[ $cmd ]] || return 0
  cmd=${cmd##*/}

  # Load the table into __nire_cod_desc, once per shell. Reload only if
  # NIRE_COD_DESC_TSV changes (a new Nix generation has a new store path).
  # Keys are "command<TAB>candidate"; values are descriptions.
  #
  # The array has to be an associative array (string keys). With a plain
  # indexed array, bash treats the text in `arr[...]` as an arithmetic
  # expression, so a lookup with `sops<TAB>--decrypt` would be an arithmetic
  # error or silently hit the wrong slot. The array is declared (as
  # associative) on the last line of this file.
  if [[ ! ${__nire_cod_desc_loaded-} || ${__nire_cod_desc_tsv-} != "$NIRE_COD_DESC_TSV" ]]; then
    __nire_cod_desc=()
    local line key cand desc
    # Read the file one line at a time. `IFS=` keeps leading/trailing spaces,
    # `-r` keeps backslashes. `< file` at `done` feeds the loop its input.
    while IFS= read -r line; do
      # Skip comment lines and lines with no tab. `$'\t'` is a tab character.
      [[ $line == '#'* || $line != *$'\t'* ]] && continue
      # `%%$'\t'*` deletes the longest suffix starting at the first tab, so
      # key is the first field. `#*$'\t'` deletes the shortest prefix ending
      # at the first tab, so line is now "candidate<TAB>description".
      key=${line%%$'\t'*}
      line=${line#*$'\t'}
      [[ $line == *$'\t'* ]] || continue   # need a second tab: three fields
      cand=${line%%$'\t'*}
      # Everything after the second tab, so a description may contain tabs.
      desc=${line#*$'\t'}
      [[ $cand && $desc ]] || continue     # skip rows with an empty field
      __nire_cod_desc["$key"$'\t'"$cand"]=$desc
    done < "$NIRE_COD_DESC_TSV"
    __nire_cod_desc_tsv=$NIRE_COD_DESC_TSV
    __nire_cod_desc_loaded=1
  fi

  # First pass: does the table have a row for ANY candidate? If not, return
  # and keep ble.sh's man-page descriptions (see "what this does" above).
  # `&&` after `[[ ... ]]` runs the next command only if the test was true;
  # `has_rows=1 && break` sets the flag and exits the loop.
  local cand bare has_rows=
  for cand in "${COMPREPLY[@]}"; do
    bare=${cand%=}   # `%=` deletes a trailing `=` if there is one
    [[ ${__nire_cod_desc["$cmd"$'\t'"$cand"]-} || ${__nire_cod_desc["$cmd"$'\t'"$bare"]-} ]] &&
      has_rows=1 && break
  done
  [[ $has_rows ]] || return 0

  # Second pass: hand every candidate to ble.sh, with a description where we
  # have one. `${!COMPREPLY[@]}` is the list of indices, not the values.
  local i desc has_desc=
  for i in "${!COMPREPLY[@]}"; do
    # Every N candidates (bleopt_complete_polling_cycle), ask ble.sh whether
    # the user has typed another key; if so, give up (148 is the status ble.sh
    # uses for "cancelled"). cand_iloop is a counter ble.sh declares as a
    # local in its calling function; bash functions can see their callers'
    # locals, so this one increments it. (If unset, arithmetic reads it as 0.)
    ((cand_iloop++%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && return 148
    cand=${COMPREPLY[i]}
    bare=${cand%=}
    desc=${__nire_cod_desc["$cmd"$'\t'"$cand"]-}
    # Not found as given, and it ends in `=`: try without the `=`.
    if [[ ! $desc && $cand == *= ]]; then
      desc=${__nire_cod_desc["$cmd"$'\t'"$bare"]-}
    fi
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

# Register the advice, if cod's completer exists in this shell.
# `ble/function#advice after <function> <advice>` means: run <advice> after
# <function> returns. It does not need to call the original itself; only
# `around` advice does.
function ble/contrib/cod-desc/adjust {
  ble/is-function __cod_complete_bash || return 0
  ble/function#advice after __cod_complete_bash ble/contrib/cod-desc/_cod_complete_bash.advice
}
ble/contrib/cod-desc/adjust

# The advice's description cache, empty until the advice loads the table.
# `declare -A` makes an associative array (string keys). Without a
# declaration, `__nire_cod_desc=()` in the advice would make an INDEXED array
# and every lookup would silently miss.
#
# `-g` makes it global, and it is needed: ble.sh loads this file with `source`
# from inside its own function (ble/util/import), and a plain `declare` inside
# a function is local to it, so `declare -A` here would be gone by the time
# the advice runs. (Reproduced with ble.sh's own ble-import in bash 5.3.)
declare -gA __nire_cod_desc=()
