# ble/contrib/cod-desc.bash -- this repo, 2026-09-25.
#
# cod's bash completer, __cod_complete_bash (defined by the `cod init $$
# bash` preamble sourced in bash.nix, registered per learned command as
# `complete -o filenames -o bashdefault -F __cod_complete_bash`), only ever
# emits plain candidate words into COMPREPLY: readarray straight from
# `cod api complete-words`, one word per line. cod has no richer mode to
# fall back on -- unlike carapace's `export` (carapace-desc.bash), its
# sqlite schema simply has no description column (Completion: HelpPageId,
# Flag, Context; confirmed against dim-an/cod v0.1.0's source), and its
# own help texts are not kept either. The descriptions come from this repo
# instead: cod-desc.tsv next to this file (command<TAB>candidate<TAB>
# description, curated, extended via `just cod-desc draft`), rendered into
# the store by blesh.nix and pointed at through NIRE_COD_DESC_TSV.
#
# This advises __cod_complete_bash the same way carapace-desc.bash advises
# _carapace_completer (both copied from ble.sh's own bash-completion
# contrib integration): registered with `after`, so the real completer
# fills COMPREPLY normally first, then -- only if this table has rows for
# the command -- the candidates are re-yielded through ble.sh's own
# candidate list via ble/complete/cand/yield, with the table's description
# where the candidate has one, which is what `bleopt complete_menu_style=desc`
# (set in .blerc) displays. If NO candidate matched a row, COMPREPLY is left
# completely untouched: ble.sh's man-page (mandb) enrichment still applies
# to it and the behaviour is exactly what it was before this file existed.
# A command absent from the table therefore costs one hash lookup, nothing
# more.
#
# Candidates are keyed WITHOUT a trailing `=`; cod serves `--opt=` for
# flags that take a value (then compopts nospace), so the lookup strips a
# trailing `=` and retries. Rows keyed with a trailing `=` would never
# match, which is why test_cod_desc.py rejects them.
#
# The deferred import is load-bearing: .blerc is sourced by ble.sh before
# bash.nix's later initExtra blocks run `cod init`, so __cod_complete_bash
# does not exist yet at .blerc read time. `ble-import -d` (see blesh.nix)
# defers this file to idle, by which point the preamble has been sourced;
# the is-function check below is the guard for sessions where it never is
# (cod not installed -- the darwin hosts -- or cod init failing).
#
# Verified 2026-09-25 by driving the real completer with ble.sh's
# primitives stubbed (cand/yield, test-limit, check-cancel logged their
# arguments instead of being live): sops's real COMPREPLY from
# `cod api complete-words` re-yielded with descriptions from the committed
# cod-desc.tsv, e.g. `--decrypt` -> "Decrypt a file and output the result
# to stdout", `-d` -> the same via a separate row, `--value-stdin=` (trailing
# = appended the way __cod_complete_bash's caller would) -> the stripped
# row; candidates absent from the table yielded plain; a command with no
# rows left COMPREPLY untouched. What that does NOT cover: the advice
# machinery firing for real under an attached ble.sh and the menu painting
# the desc column on screen -- the same limit carapace-desc.bash's
# verification acknowledged. If descriptions don't show for real: check
# NIRE_COD_DESC_TSV is set and names an existing store path (it is a plain
# shell variable set in .blerc, not exported), and that `complete -p <cmd>`
# actually shows __cod_complete_bash -- cod registers per command it has
# learned, and an unlearned command never reaches this advice at all.

function ble/contrib/cod-desc/_cod_complete_bash.advice {
  [[ ${BLE_ATTACHED-} ]] || return 0
  ((ADVICE_EXIT==0)) || return 0
  ((${#COMPREPLY[@]}>=1)) || return 0
  [[ ${NIRE_COD_DESC_TSV-} && -s "$NIRE_COD_DESC_TSV" ]] || return 0
  ble/complete/source/test-limit "${#COMPREPLY[@]}" || return 0

  local cmd=${COMP_WORDS[0]-}
  [[ $cmd ]] || return 0
  cmd=${cmd##*/}

  # Load the table once per session, and again only if .blerc ever points
  # NIRE_COD_DESC_TSV at a different store path (a new generation). Keys
  # are "command<TAB>candidate"; the TSV's three fields are split on the
  # first two tabs so a description may itself contain tabs. The array is
  # declared -A at the bottom of this file -- a plain array=() assignment
  # inside this function would create it INDEXED, every subscript would
  # then evaluate as arithmetic, and every lookup would silently miss.
  if [[ ! ${__nire_cod_desc_loaded-} || ${__nire_cod_desc_tsv-} != "$NIRE_COD_DESC_TSV" ]]; then
    __nire_cod_desc=()
    local line key cand desc
    while IFS= read -r line; do
      [[ $line == '#'* || $line != *$'\t'* ]] && continue
      key=${line%%$'\t'*}
      line=${line#*$'\t'}
      [[ $line == *$'\t'* ]] || continue
      cand=${line%%$'\t'*}
      desc=${line#*$'\t'}
      [[ $cand && $desc ]] || continue
      __nire_cod_desc["$key"$'\t'"$cand"]=$desc
    done < "$NIRE_COD_DESC_TSV"
    __nire_cod_desc_tsv=$NIRE_COD_DESC_TSV
    __nire_cod_desc_loaded=1
  fi

  # Take over only when the table knows this command AND at least one
  # candidate in COMPREPLY: otherwise leaving COMPREPLY alone lets ble.sh's
  # mandb enrichment attach man-page descriptions this table may not have.
  local cand bare has_rows=
  for cand in "${COMPREPLY[@]}"; do
    bare=${cand%=}
    [[ ${__nire_cod_desc["$cmd"$'\t'"$cand"]-} || ${__nire_cod_desc["$cmd"$'\t'"$bare"]-} ]] &&
      has_rows=1 && break
  done
  [[ $has_rows ]] || return 0

  local i desc has_desc=
  for i in "${!COMPREPLY[@]}"; do
    ((cand_iloop++%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && return 148
    cand=${COMPREPLY[i]}
    bare=${cand%=}
    desc=${__nire_cod_desc["$cmd"$'\t'"$cand"]-}
    if [[ ! $desc && $cand == *= ]]; then
      desc=${__nire_cod_desc["$cmd"$'\t'"$bare"]-}
    fi
    if [[ $desc ]]; then
      ble/complete/cand/yield word "$cand" "$desc"
      has_desc=1
    else
      ble/complete/cand/yield word "$cand"
    fi
    builtin unset -v 'COMPREPLY[i]'
  done
  COMPREPLY=("${COMPREPLY[@]}")
  [[ $has_desc ]] && bleopt complete_menu_style=desc
}

function ble/contrib/cod-desc/adjust {
  ble/is-function __cod_complete_bash || return 0
  ble/function#advice after __cod_complete_bash ble/contrib/cod-desc/_cod_complete_bash.advice
}
ble/contrib/cod-desc/adjust

# The advice's description cache. Declared HERE rather than inside the
# function: a declare -A inside a function is local to it, and the cache
# must live across invocations. See the comment in the advice body for the
# failure an undeclared (indexed) array produced.
declare -A __nire_cod_desc=()
