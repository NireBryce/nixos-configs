# 29. Ordering fixes do not reach code that schedules itself later

_Last modified: 2026-09-29_

§29 of [lessons-learned.md](../lessons-learned.md), the index that files every lesson by when it applies; this is §29's full account.

`ble-attach` ran before seven integrations, so the fix was `mkOrder`. That was
correct and insufficient: one thing binding `Ctrl-R` was not in `.bashrc` at all.
`.blerc` registers it with `ble-import -d`, which loads "in idle time" — after
the whole file, `ble-attach` included.

Nothing done to a file's order controls something that has deferred itself out
of that file. The hook must attach to the deferred thing — here `ble-import -C`.

Second half, which the obvious fix gets wrong: **unbinding a key in a system
that replaced the underlying mechanism leaves it dead, not falling back.** ble.sh
replaces readline outright, so removing fzf's binding would not have revealed
atuin's underneath.
