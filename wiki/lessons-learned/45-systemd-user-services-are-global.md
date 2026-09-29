# 45. NixOS `systemd.user.services` is global — every user manager reads it, and they all race to start it

_Last modified: 2026-09-29_

§45 of [lessons-learned.md](../lessons-learned.md), the index that files every lesson by when it applies; this is §45's full account.

2026-09-08, cube (PR #196's `opencode-server`). A NixOS user unit lands
in `/etc/systemd/user` and `wantedBy` enables it in *every* manager —
including sddm's (`user@175`, alive whenever the greeter session is).
sddm's copy bound port 3003 first; elly's crash-looped on `ServeError`,
and `opencode attach` reached a server running as sddm (cwd
`/var/lib/sddm` — attach defaults to the server process's cwd). What
pinned it: the sole `serve` process's parent was `user@175.service`, and
`ss -tlnp` showed the listener was not elly's. Fix:
`unitConfig.ConditionUser = "elly"` — a no-op in every other user's
manager. Rationale lives in the module comment
(`hosts/cube/configuration/opencode-server-cube.nix`; since 2026-09-26
`general-config/homelab/coding-agent/opencode/opencode-server.nix`).
