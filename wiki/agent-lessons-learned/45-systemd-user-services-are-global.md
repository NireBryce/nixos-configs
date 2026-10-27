# 45. NixOS `systemd.user.services` is global — every user manager reads it, and they all race to start it

_Last modified: 2026-09-29_

## Index entry

§45 in [agent-lessons-learned.md](../agent-lessons-learned.md), which keeps a one-line version of every lesson, filed by when it applies. This page is the longer write-up.

## The lesson

2026-09-08, cube (PR #196's coding-agent server unit). A NixOS user unit lands
in `/etc/systemd/user` and `wantedBy` enables it in *every* manager —
including sddm's (`user@175`, alive whenever the greeter session is).
sddm's copy bound port 3003 first; elly's crash-looped on a bind error,
and the client reached a server running as sddm (cwd
`/var/lib/sddm` — it defaults to the server process's cwd). What
pinned it: the sole `serve` process's parent was `user@175.service`, and
`ss -tlnp` showed the listener was not elly's. Fix:
`unitConfig.ConditionUser = "elly"` — a no-op in every other user's
manager. The module has since been removed
(2026-10-14); the fix is the same for any NixOS user unit.
