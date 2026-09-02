# `monitoring` — history

## Contents

- [The `secret_key` regression, twice](#the-secret_key-regression-twice)
- [An unrelated failure in the same activation](#an-unrelated-failure-in-the-same-activation)
- [See also](#see-also)

How [monitoring](monitoring.md)'s `grafana-secret-key-setup.service` came
to exist, split out 2026-09-03 so that page's "The `secret_key` trap"
section can stay about the mechanism as it works today rather than the
road to it.

## The `secret_key` regression, twice

A `warnings` entry describing a two-step manual fix used to sit where the
unit is now — fixed by hand once (2026-08-23), then found **regressed to
the same `root:root` state** on a live re-check 2026-08-24,
`grafana.service` crash-looping the whole time nobody checked. One
regression was reason enough not to trust a second hand fix:
`grafana-secret-key-setup.service` (`grafana.nix`) replaced the warning —
a oneshot ordered before `grafana.service` on every activation that
generates the secret only if missing and unconditionally reasserts
ownership/mode, modeled on `services.forgejo`'s upstream
`forgejo-secrets.service` ([git-forge](git-forge.md)). Checking
`services.grafana`'s nixpkgs module first showed this isn't idiomatic *to*
Grafana: nixpkgs removed its `secretKeyFile` option in favor of exactly
this "the deployer manages it" file-provider approach, warning there's no
official way to rotate `secret_key` — so the unit only ever *creates* a
missing file, never regenerates; only ownership/mode are safe to reassert,
and that's the part that kept regressing.

Confirmed working end to end, 2026-08-24: `sudo systemctl restart
grafana.service` (needed once — a brand-new unit added by `switch` isn't
pulled into an already-running service) ran the setup unit first
(`0/SUCCESS`), and `grafana.service` came back up with the secret file's
mtime unchanged and ownership `grafana:grafana`.

## An unrelated failure in the same activation

A third, unrelated thing broke in the same `switch` that isn't part of
this category: the sandbox VM failed with `network 'default' is not
active` — [virtualization](virtualization.md)'s libvirt default network
never being started. Two independent failures in one activation log were
easy to conflate; they had nothing to do with each other.

## See also

- [monitoring](monitoring.md) — the mechanism as it works today.
- [git-forge](git-forge.md) — `forgejo-secrets.service`, the upstream
  pattern this unit is modeled on.
