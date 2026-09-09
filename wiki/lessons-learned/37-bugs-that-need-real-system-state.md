# 37. Some bugs need real system state to exist at all — no amount of building or reading the artifact finds them

_Last modified: 2026-09-09_

§37 of [lessons-learned.md](../lessons-learned.md#37-some-bugs-need-real-system-state-to-exist-at-all--no-amount-of-building-or-reading-the-artifact-finds-them) — that page keeps the one-line version of every lesson; this is §37's full account.

`nire-cube`'s first real `just switch` with the `monitoring` category and
`nire-llm-sandbox`'s network fix both wired in (2026-08-23) failed two
units, and both bugs share a shape one level past §36's: not "the built
artifact's content is wrong" but "the artifact is exactly right, and the bug
only exists once real system state it depends on shows up at runtime."

1. Grafana's `secret_key` pointed at
   `$__file{/persist/secrets/grafana-secret-key}` — correct syntax, and the
   nixpkgs assertion requiring *some* value for the option was satisfied.
   `grafana.service` still failed, because the file `sudo install -D -m600`
   created was `root:root`, and `services.grafana` runs as `User =
   "grafana"` (a fact about the *systemd unit*, nowhere near the Nix
   expression that set the option). No `nix eval`, and no reading back the
   generated config file, would have shown this — the config file's
   *content* was correct throughout; only the *filesystem permissions* on a
   path outside the Nix store, set by a command run outside of Nix
   entirely, were wrong.
2. `libvirt-vm-llm-sandbox.service` failed with `network 'default' is not
   active` despite `virsh define` succeeding immediately before it in the
   same script. The domain XML was correct, the activation script was
   correct — the failure depended on libvirtd's own *runtime* network
   state (defined vs. started), which is neither part of the Nix
   expression nor visible in any built artifact, only in `virsh net-list`
   against a live daemon.

**Both bugs were only visible by actually running `just switch` on the real
host and reading `systemctl status`/`journalctl` afterward — not by
evaluating, not by building, not by reading back a generated file.** That's
a third rung past §25 ("evaluates ≠ works") and §36 ("a well-typed value can
still be wrong, build and read the artifact"): some correctness depends on
state that doesn't exist anywhere until the real activation runs on the
real machine — a service's runtime UID, a daemon's own runtime object
state. For anything shaped like that (a file a *service* reads rather than
Nix, a resource a *daemon* manages rather than a NixOS option), the only
real test is the switch itself, and `systemctl status`/`journalctl` after
it — matching this repo's own standing rule ("did it work before?", "force a
toplevel") one step further: even a forced toplevel and a successful
activation don't prove every unit inside it actually started.
