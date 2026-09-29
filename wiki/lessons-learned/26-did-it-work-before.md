# 26. "Did it work before?" is one command, and it beats reasoning

_Last modified: 2026-09-29_

§26 of [lessons-learned.md](../lessons-learned.md), the index that files every lesson by when it applies; this is §26's full account.

Twice I built a causal story the journal demolished. Vicinae crash-looping was
not what made the machine unusable — the user had driven a rollback from a working
session. The stage-1 migration did not cause the suspend hang — hybrid-sleep had
been writing 2.1G images for months under scripted stage 1.

`journalctl --list-boots` plus one grep settled both, and a third question
(whether handheld-daemon had ever worked) in one line. Both times I ran it only
after being challenged.

**On a machine with persistent logs, "is this new?" is cheaper than any argument
about mechanism, and belongs before it.**
