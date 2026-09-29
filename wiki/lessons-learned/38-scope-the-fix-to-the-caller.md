# 38. A fix scoped to what actually asked for it beats a general one — asking "does this affect the host that didn't ask" caught it before writing the wrong mechanism

_Last modified: 2026-09-29_

§38 of [lessons-learned.md](../lessons-learned.md), the index that files every lesson by when it applies; this is §38's full account.

The obvious fix for #37's network-not-active bug was a host-wide systemd
unit, in the shared `virtualization` category, unconditionally starting
libvirt's default network at boot. It would have worked. It was also about
to ship as the first draft, until asked directly: does this have security
implications on `nire-durandal`, which imports `virtualization` too and
never had this problem?

It does. `vm-networking.nix`'s `trustedInterfaces = [ "virbr0" ]` already
unconditionally trusts that whole bridge — pre-existing, not something the
fix would add — but a host-wide unit would change *when* that trust is
actually live: from "only while a VM is actually running" to "for the
machine's entire uptime, whether or not anything ever uses the bridge."
Fixed instead inside `VMs/_lib/libvirt-vm.nix`'s own per-VM activation
script, gated on the `networked` parameter each VM already declares — so a
host with no networked VM defined through that generator (durandal, at the
time) gets zero behavior change, confirmed by drvPath rather than assumed.

**The general fix and the scoped fix produce identical behavior on the host
that has the bug. They only diverge on hosts that don't — and that
divergence is exactly the kind of thing that's invisible until someone
asks "who else does this touch" before writing it, not after.** Scoping a
fix to the actual caller that needs it, rather than to the category or
host class it happens to live in, is the same "if something shared needs
to be optional, a category is the mechanism" instinct `CLAUDE.md`'s
Architecture section already states — applied one level down, to a single
behavior inside one already-shared module rather than to category
membership itself.
