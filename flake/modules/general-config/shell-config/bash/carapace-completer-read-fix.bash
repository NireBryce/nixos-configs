# This file, flake/modules/general-config/shell-config/bash/
# carapace-completer-read-fix.bash, patches one line inside carapace's
# generated bash completion function. Written 2026-08-24.
#
# TEMPORARY. Works around a ble.sh/carapace interaction (issue #75); when to
# remove it and how: wiki/temporary-patches-and-hacks.md, carapace-read-fix.md.
#
# The bug: while typing at normal speed with carapace completing, the
# terminal shows `-bash: read: `': not a valid identifier`. Cause: `source
# <(carapace _carapace bash)` (bash.nix) defines _carapace_completer, which
# contains
#
#     IFS=$'\001' read -r -d '' nospace data <<<"${data}"
#
# `read` splits the text in `data` on the separator `IFS` (here the byte SOH,
# 0x01; terminals don't draw it, so `declare -f` output looks like `IFS=''`;
# confirm with `od -c`). ble.sh replaces the `read` builtin shell-wide and,
# while a completer runs, every `bleopt_complete_polling_cycle` reads (50 by
# default) it checks whether the user typed another key. If that check hits
# this line, the read is abandoned and its arguments come out split
# character by character, hence the error. It happens with carapace's stock
# completer alone (checked on nire-cube), so it is not this repo's completion
# code. Full account: wiki/categories/shell-config/blesh.md, wiki/
# agent-lessons-learned.md #39, issue #72.
#
# The fix removes the `read` by replacing that line, in the function's source
# text, with parameter expansions:
#
#     nospace=${data%%<SOH>*}; data=${data#*<SOH>}$'\n'
#
# carapace's data is `<nospace flag><SOH><completions>`, e.g. `false<SOH>--amend`
# (see `carapace git bash git commit --am | od -c`). `${data%%<SOH>*}` deletes
# the longest suffix starting at the first SOH, leaving the flag. `${data#
# *<SOH>}` deletes the shortest prefix ending at the first SOH, leaving the
# completions. The trailing `$'\n'` reproduces the newline the original's
# `<<<` here-string added: the next lines of _carapace_completer do `mapfile`
# and then `unset COMPREPLY[-1]` to drop a trailing empty entry, and without
# that newline the unset would drop the last real candidate.
#
# Applied by: `declare -f` prints the function's source, `${text/old/new}`
# swaps the line, `eval` redefines the function.
#
# Order: this must run after `source <(carapace _carapace bash)` (or there is
# nothing to patch) and before carapace-desc.bash's advice wraps the function
# (installed later, from .blerc). bash.nix sources this file right after the
# carapace line. If _carapace_completer is not defined, nothing happens.
#
# Tripwire: the match is exact text. If a carapace update changes the line,
# the file prints a warning to stderr in every new shell instead of silently
# not applying. That warning means the fix stopped applying, not that anything
# is broken; see carapace-read-fix.md, "How to undo".

if declare -F _carapace_completer > /dev/null; then
  # The SOH byte. `$'\001'` is bash's escape syntax for byte 0x01.
  __carapace_read_fix_sep=$'\001'
  # The exact text to find. It uses double quotes, so that:
  #   - the single quotes inside need no escaping,
  #   - `\$` and `\"` produce a literal `$` and `"` (so `${data}` stays text
  #     rather than being expanded now),
  #   - `${__carapace_read_fix_sep}` IS expanded, putting a real SOH byte in
  #     the search string rather than the two characters `''`.
  __carapace_read_fix_search="IFS='${__carapace_read_fix_sep}' read -r -d '' nospace data <<< \"\${data}\""
  # What to put there. Same quoting; `\${data%%...}` and `\$'\n'` stay literal
  # text for the function body, and the separator byte is expanded.
  __carapace_read_fix_replace="nospace=\${data%%${__carapace_read_fix_sep}*}; data=\${data#*${__carapace_read_fix_sep}}\$'\n'"
  # The function's current source text.
  __carapace_read_fix_body=$(declare -f _carapace_completer)
  # `${var/pattern/replacement}` replaces the first match. The quotes around
  # both make bash treat them as literal text, not glob patterns.
  __carapace_read_fix_patched=${__carapace_read_fix_body/"$__carapace_read_fix_search"/"$__carapace_read_fix_replace"}
  if [[ $__carapace_read_fix_patched != "$__carapace_read_fix_body" ]]; then
    # Text changed, so the line was found. Redefine the function from it.
    eval "$__carapace_read_fix_patched"
  else
    # Nothing changed: carapace no longer emits the exact line this patches.
    # Doing nothing quietly would hide that (see "the tripwire" above).
    echo 'carapace-completer-read-fix.bash: expected line not found in' \
      '_carapace_completer -- fix did not apply, check carapace --version' >&2
  fi
  # Remove the temporary variables so they do not stay in the user's shell.
  unset -v __carapace_read_fix_sep __carapace_read_fix_search \
    __carapace_read_fix_replace __carapace_read_fix_body __carapace_read_fix_patched
fi
