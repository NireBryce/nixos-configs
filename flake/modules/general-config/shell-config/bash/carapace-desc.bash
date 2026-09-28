# ble/contrib/carapace-desc.bash -- this repo, 2026-08-22.
#
# carapace's own bash completer, _carapace_completer (registered by
# `source <(carapace _carapace bash)` in bash.nix), only ever emits plain
# candidate words into COMPREPLY. Confirmed by reading its generated
# function: it builds COMPREPLY straight from `carapace "$cmd" bash`
# (mapfile -t COMPREPLY < <(...)), and that mode is deliberately
# bash-COMPREPLY-shaped -- bash's own completion protocol has no
# description slot. carapace tracks real per-candidate descriptions
# internally regardless; they come out of a different mode,
# `carapace <cmd> export -- <words...>`, as JSON:
#   {"values":[{"value":"--amend","description":"amend previous commit",...}]}
#
# This advises _carapace_completer the same way ble.sh's own
# bash-completion.bash contrib integration advises bash-completion's
# _comp_command_offset (see that file, function
# ble/contrib/integration:bash-completion/mandb/_comp_command_offset.advice,
# for the template this is copied from): register with `after`, which
# means ble.sh's own advice framework (ble/function#advice/.proc, ble.sh
# lines ~4053-4072) calls the real completer first and populates COMPREPLY
# normally, then afterward -- and only afterward -- re-derives descriptions
# for those same candidate strings from `export` and re-yields them
# through ble.sh's own candidate list via ble/complete/cand/yield, which is
# what `bleopt complete_menu_style=desc` (set in this same .blerc) actually
# reads. If the export call or the JSON parse fails for any reason,
# COMPREPLY is left completely untouched and candidates fall back to
# carapace's plain word list, same as before this file existed.
#
# Verified 2026-08-22, but short of a live interactive Tab press. Checked
# by hand that `ble/complete/cand/yield word "$cand" "$desc"` is the right
# call (ble/complete/action:word/get-desc -> action:plain/get-desc reads
# DATA as the description verbatim, core-complete.sh:1218-1220) and that
# `after`-type advice does not need to call ble/function#advice/do itself
# (ble.sh:4053-4072, only `around` does -- see the dnf5 advice in
# bash-completion.bash for a case that does). Beyond that, ran this
# function for real: sourced the actual `carapace _carapace bash` output
# to get the real _carapace_completer, drove it for `git commit --a`
# (COMPREPLY came back `--ahead-behind --all --allow-empty
# --allow-empty-message --amend --author`, matching plain `carapace git
# bash` exactly), then ran this file's advice function against that real
# COMPREPLY with ble.sh's own primitives (cand/yield, bleopt, test-limit,
# check-cancel) stubbed to log their arguments instead of ble.sh being
# attached. All 6 candidates matched a real `carapace git export`
# description and were re-yielded correctly, e.g. `--amend` -> "amend
# previous commit"; COMPREPLY ended up correctly cleared. What that does
# NOT cover: ble.sh's own advice-registration machinery actually firing
# `ble/function#advice/.proc` for real (stubbed here, not exercised) and
# the menu actually painting the desc column on screen. If descriptions
# still don't show once attached for real: check `carapace <cmd> export
# -- ...` still returns non-empty `.values[].description` for a real
# candidate, and check candidates in COMPREPLY actually string-match
# `.value` -- a mismatch (e.g. a trailing `=` bash added that carapace's
# export value doesn't have) would silently fall through to "no
# description" per candidate rather than erroring.

function ble/contrib/carapace-desc/_carapace_completer.advice {
  [[ ${BLE_ATTACHED-} ]] || return 0
  ((ADVICE_EXIT==0)) || return 0
  ((${#COMPREPLY[@]}>=1)) || return 0
  ble/complete/source/test-limit "${#COMPREPLY[@]}" || return 0

  local cmd=${COMP_WORDS[0]-}
  [[ $cmd ]] || return 0

  local json
  json=$(command carapace "$cmd" export -- "${COMP_WORDS[@]:0:COMP_CWORD+1}" 2>/dev/null)
  [[ $json ]] || return 0

  local tsv
  tsv=$(command jq -r '
      (.values // [])[]
      | select(.value != null and .value != "")
      | [.value, (.description // "")] | @tsv
    ' <<<"$json" 2>/dev/null)
  [[ $tsv ]] || return 0

  local -A desc_of=()
  local value desc
  while IFS=$'\t' read -r value desc; do
    [[ $value ]] && desc_of[$value]=$desc
  done <<<"$tsv"
  ((${#desc_of[@]})) || return 0

  local i cand has_desc=
  for i in "${!COMPREPLY[@]}"; do
    ((cand_iloop++%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && return 148
    cand=${COMPREPLY[i]}
    desc=${desc_of[$cand]-}
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

function ble/contrib/carapace-desc/adjust {
  ble/is-function _carapace_completer || return 0
  ble/function#advice after _carapace_completer ble/contrib/carapace-desc/_carapace_completer.advice
}
ble/contrib/carapace-desc/adjust
