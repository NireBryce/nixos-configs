# 39. A live interactive bug needs a live interactive repro — `ssh host 'cmd'` is not the same session a human types into

_Last modified: 2026-09-09_

§39 of [lessons-learned.md](../lessons-learned.md#39-a-live-interactive-bug-needs-a-live-interactive-repro--ssh-host-cmd-is-not-the-same-session-a-human-types-into) — that page keeps the one-line version of every lesson; this is §39's full account.

Reported 2026-08-24: "weird completion errors" over SSH to `nire-cube`,
`-bash: read: `': not a valid identifier`, appearing while typing (before
any Tab) and sometimes on Tab itself, for ordinary commands like `git co`.

The instinct was to read `bash.nix`/`blesh.nix`/`carapace-desc.bash` and
reason about it, but reading found nothing wrong, and `ssh nire-cube 'bash -ic
"..."'` couldn't reproduce it either — no pty, so `[[ $- == *i* ]]` in
bash.nix's own ble.sh-attach line never fires, exactly the trap that line's
own neighboring comments don't warn about because nobody had hit it yet.
Getting a real pty (`ssh -tt`) and typing real keystrokes into it (built as
`ssh-pty-drive.py` this session, later generalized beyond SSH, renamed and
published as [`terminal-puppeteer`](https://github.com/NireBryce/terminal-puppeteer)
— see its own README) reproduced the exact error on the first try.

Tracing (monkey-patching `ble/bash/read` live to log every real `read`
builtin call and its caller stack, then reproducing again) found the actual
call chain: ble.sh's own auto-complete/progcomp machinery globally shadows
the `read` builtin, and while a registered completer is running it installs
`_ble_builtin_read_hook`, a safety net that periodically checks whether the
user has kept typing (`ble/complete/progcomp/.check-limits`, tripped every
`bleopt_complete_polling_cycle` reads — 50 by default — precisely the "am I
being too slow, is there more input already queued" check ble.sh runs
*constantly* during normal-speed typing, not a rare edge case) and, if so,
redirects the in-flight `read` to `/dev/null` and cancels. carapace's own
generated `_carapace_completer` (`source <(carapace _carapace bash)` in
`bash.nix` — third-party output, not this repo's code) has exactly one
`read` call in it, and its visible form — `IFS='' read -r -d '' nospace data
<<< "${data}"` — is a misread that survived several rounds of this exact
tracing before `od -c` caught it: that first `''` is not empty, it's two
single quotes around a literal SOH (0x01) control byte that a terminal
just doesn't render, so it *looks* like an empty string in every plain
`echo`/`grep`/`type` capture, including the ones this session took first.
When that read call is the one caught by the cancellation fallback, its
args come back corrupted — split character-by-character rather than into
the two variable names — which is what produces
`read: `': not a valid identifier`, repeatedly, for any carapace-routed
command, on any keystroke fast enough to leave more input queued when the
50-read check lands.

**This is not `carapace-desc.bash`'s bug.** That file (added the day before,
2026-08-22, and flagged in its own header as unverified against a live Tab
press) was the first suspect precisely because it was newest and explicitly
marked unverified. Confirmed innocent by removing its advice and
re-`source`-ing carapace's completer plain: the error still fires with zero
of this repo's completion code involved. It is a genuine interaction bug
between carapace's stock bash completer and ble.sh's own live-typing
cancellation path, exposed by this repo wiring carapace into `complete -F`
for the first time — not introduced by anything added on top of it.

Also worth naming plainly: **this exact bug was already found and written
up two days earlier**, 2026-08-22, in
[`wiki/categories/shell-config/blesh.md`](../categories/shell-config/blesh.md)
— pinned to "somewhere inside ble.sh's global `read` override" and left
open. This session re-derived the whole thing from a live pty before
checking whether the wiki already had it, which cost real effort the
earlier session's own diagnosis would have saved. `wiki/README.md` exists
specifically so a finding like that isn't rediscovered by grepping the
tree — check it before re-deriving, not after.

The fix that tested clean against carapace's real generated function on
`nire-cube` (avoid ever calling `read` for that line —
`nospace=${data##*$sep}; data=${data%$sep*}`, `$sep` the real SOH byte,
instead of `IFS=$sep read -r -d '' nospace data <<< "${data}"`) sidesteps
ble.sh's read-shadow entirely rather than trying to out-think it, and is now
in the tree:
`flake/modules/nire/shell-config/bash/carapace-completer-read-fix.bash`,
sourced from `bash.nix` right after `source <(carapace _carapace bash)`,
patching `_carapace_completer`'s own body via `declare -f` plus a textual
substitution — with a loud stderr warning if the line it's looking for ever
stops matching, so carapace changing its generated template doesn't make
this silently do nothing. Confirmed three ways: evaluates and renders into
`programs.bash.initExtra` correctly with `just modules` clean; the
substitution reproduces the real SOH byte exactly when checked with `od -c`
against carapace's actual output, not by eye; and applied live, by hand, to
the real `_carapace_completer` on `nire-cube` and driven through four
different completions (`git co`, `git commit --amend --no-e`, `git checkout
-`, `git log --pretty=onel`, each Tab-completed) with zero `read` errors,
where every one of those reliably produced the error before the fix.
**Confirmed through a real `just switch`, same day.** `nixos-rebuild
list-generations` on `nire-cube` shows generation 10 (built/switched
2026-08-24 04:34) as current, and its toplevel matches evaluating
`nire-cube` fresh off the merged `main` exactly — not just a generation
that happened to get built, actually switched to and active. Re-ran the
same live repro against the switched host with `terminal-puppeteer`
(`git co`, `git commit --amend --no-e`, `git checkout -`,
`git log --pretty=onel`, `git diff --sta`, each Tab-completed, several
passes): zero `read` errors, where every one of those reliably produced
the error before the fix. Also checked the fix's own tripwire — the
`expected line not found` warning it prints if its textual substitution
ever stops matching carapace's generated function — and it doesn't fire on
a fresh shell, meaning the patch is actually applying, not silently
skipping while the bug happens to not trigger this time. This is the
"evaluating and building both stop short of runtime behaviour" pattern
(§25, §36, §37) resolved the ordinary way: build, switch, then check the
real thing, not the artifact.
