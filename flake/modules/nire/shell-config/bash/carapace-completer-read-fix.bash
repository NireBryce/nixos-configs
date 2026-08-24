# carapace-completer-read-fix.bash -- this repo, 2026-08-24.
#
# Works around a real bug, found live on nire-cube and written up in
# `claude cave/lessons-learned.md` #39: carapace's own generated
# _carapace_completer (source <(carapace _carapace bash), in bash.nix --
# third-party output, not this repo's code) ends with a line whose visible
# form is
#
#   IFS='' read -r -d '' nospace data <<< "${data}"
#
# but is NOT actually an empty-string IFS -- that first `''` is two single
# quotes around a literal SOH (0x01) control byte that just doesn't render
# in a terminal, confirmed with `od -c` on the real `declare -f
# _carapace_completer` output, not by eye. (Carapace's own raw stdout,
# before bash ever parses it, spells the same byte as the source escape
# `$'\001'` with no space before `<<<` -- cosmetically different text for
# the same value; once bash.nix's `source <(carapace _carapace bash)` has
# parsed it once, `declare -f` always re-serializes it as the raw byte with
# a space, regardless of which spelling carapace used. This file works on
# the post-source form, so that's the only form it needs to match.)
#
# That specific `read` call is the one ble.sh's own auto-complete machinery
# is most likely to catch mid-flight: ble.sh shadows the `read` builtin
# everywhere, and while any registered completer is running it installs a
# cancellation safety net (_ble_builtin_read_hook) that checks, every
# `bleopt_complete_polling_cycle` reads (50 by default), whether the user is
# still typing -- which during ordinary fast typing is often true, not a
# rare condition. When THIS read is the one caught by that check, its args
# come back split character-by-character instead of into the two variable
# names, which is what produces the visible
# `-bash: read: `': not a valid identifier` -- repeatedly, for any
# carapace-routed command, while typing at normal speed.
#
# Confirmed on nire-cube that this happens with carapace's completer alone,
# no advice from carapace-desc.bash involved -- it is not this repo's
# completion code misbehaving, it is this one `read` call losing a race
# against ble.sh's own cancellation path. The fix is to not call `read`
# there at all, so there is nothing for ble.sh's read-shadow to catch:
# `data` is joined on that same SOH byte (the real completion output, then
# the nospace flag), and splitting on the last occurrence with parameter
# expansion reads it identically without ever going through a builtin
# ble.sh can intercept.
#
# This has to run AFTER carapace's own source line (so _carapace_completer
# already exists) and BEFORE carapace-desc.bash's advice wraps it (so the
# advice ends up wrapping this patched version, not the original) -- bash.nix
# sources this file directly after `source <(carapace _carapace bash)`,
# and carapace-desc.bash's own advice is only installed later, from .blerc,
# when ble.sh attaches. Guarded the same way carapace-desc's own adjust
# function is: do nothing if _carapace_completer isn't defined.
if declare -F _carapace_completer > /dev/null; then
  __carapace_read_fix_sep=$'\001'
  # Built with double quotes (not single) so the embedded single quotes
  # need no escaping and `\$` keeps `${data}` literal rather than expanding
  # it here; $__carapace_read_fix_sep itself is a real expansion, giving
  # the search string an actual SOH byte rather than the two-character
  # text `''`.
  __carapace_read_fix_search="IFS='${__carapace_read_fix_sep}' read -r -d '' nospace data <<< \"\${data}\""
  __carapace_read_fix_replace="nospace=\${data##*${__carapace_read_fix_sep}}; data=\${data%${__carapace_read_fix_sep}*}"
  __carapace_read_fix_body=$(declare -f _carapace_completer)
  __carapace_read_fix_patched=${__carapace_read_fix_body/"$__carapace_read_fix_search"/"$__carapace_read_fix_replace"}
  if [[ $__carapace_read_fix_patched != "$__carapace_read_fix_body" ]]; then
    eval "$__carapace_read_fix_patched"
  else
    # carapace changed its generated template and no longer contains the
    # exact line this patches -- silently doing nothing here would mean
    # the bug (or whatever carapace replaced it with) goes unnoticed.
    echo 'carapace-completer-read-fix.bash: expected line not found in' \
      '_carapace_completer -- fix did not apply, check carapace --version' >&2
  fi
  unset -v __carapace_read_fix_sep __carapace_read_fix_search \
    __carapace_read_fix_replace __carapace_read_fix_body __carapace_read_fix_patched
fi
