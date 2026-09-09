# 40. A failed systemd unit doesn't mean the thing it manages is down — check the resource, not just the unit

_Last modified: 2026-09-09_

§40 of [lessons-learned.md](../lessons-learned.md#40-a-failed-systemd-unit-doesnt-mean-the-thing-it-manages-is-down--check-the-resource-not-just-the-unit) — that page keeps the one-line version of every lesson; this is §40's full account.

`nire-llm-sandbox` finally got a real end-to-end test 2026-08-23/24: `just
switch` on `nire-cube`, watching `libvirt-vm-llm-sandbox.service`. It failed.
Then, after a fix, it failed again, differently. Then, after a second fix,
it failed a third time, differently again. Each time the instinct was "the
VM isn't coming up" — wrong every time after the first. `virsh dominfo
llm-sandbox` on the real host showed `State: running` with climbing CPU
time through fixes two and three both: the guest booted once, on the first
successful `virsh define` + `virsh start`, and stayed up continuously while
the *systemd unit* kept failing on an unrelated step (`virsh define`
re-run, idempotency of the redefine) on every activation after that.

The three failures, in order, and why none of them were visible to `nix
eval` or a build — only to reading `journalctl`/`systemctl status` against
the real host:

1. `error: Requested operation is not valid: network 'default' is not
   active` — libvirt ships its default NAT network *defined* but never
   *started*; nothing in NixOS's own libvirtd module starts it. Fixed by
   having the VM's own activation script start it when needed
   (`VMs/_lib/libvirt-vm.nix`), scoped per-VM rather than host-wide per
   lesson #38's reasoning.
2. `error: command 'net-list' doesn't support option --state-active` — the
   fix for (1) checked "is the network already active" with a flag that
   doesn't exist on virsh 12.4.0. The check errored, `set -e`-adjacent logic
   fell through to an unconditional `net-start`, which then failed with
   `network is already active` on every activation after the first. Fixed
   by dropping the nonexistent flag — plain `net-list --name` already lists
   active-only networks with neither `--all` nor `--inactive` given.
3. `error: operation failed: domain 'llm-sandbox' already exists with uuid
   ...` — the domain XML had no `<uuid>`. Omitting it doesn't mean "keep
   whatever UUID is already registered under this name"; it means libvirt
   generates a *brand new random UUID on every single parse*, so the second
   and every later `virsh define` collided with the domain object the first
   one created. Fixed by giving the generator a required `uuid` parameter
   and, for the already-running `llm-sandbox`, adopting the UUID libvirt
   had already assigned rather than minting a fresh one — the fix a human
   would reach for on reflex (regenerate a clean UUID) would have collided
   with the running guest exactly the way (3) itself did.

None of these three would have been caught by evaluating the module,
building the toplevel, or even reading the generated activation script by
eye — each is a fact about how the *real* `virsh` on the *real* host
behaves (a flag it does or doesn't support, whether a network is already
up, what UUID a domain is already registered under), true only at runtime.
Consistent with lesson #37. What's new here: **when a unit fails, check
what it manages before assuming the failure means that thing isn't
running.** `systemctl status` alone said "failed" three times in a row;
`virsh dominfo` said "running" for two of those three, with a real host
walked to over SSH (`ts-cube` via Tailscale) precisely so the check wasn't
taken on faith. Confirmed clean end state, 2026-08-24: `systemctl status
libvirt-vm-llm-sandbox.service` is `active (exited)` / exit 0, `virsh
dominfo llm-sandbox` shows `running`, `Persistent: yes`. Each of the three
fixes was also confirmed not to touch `nire-durandal` (byte-identical
toplevel drvPath) before being applied to cube, same discipline as #38.
