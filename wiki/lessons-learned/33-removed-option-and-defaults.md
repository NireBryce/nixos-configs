# 33. A removed option is not an ignored option, and defaults are worth reading

_Last modified: 2026-09-29_

§33 of [lessons-learned.md](../lessons-learned.md), the index that files every lesson by when it applies; this is §33's full account.

Three separate restatements went into one afternoon's libvirt module, and the
tree caught none of them:

- `virtualisation.libvirtd.qemu.ovmf` — every wiki page and blog post still
  tells you to set this. nixpkgs **removed** the submodule; all OVMF images
  QEMU distributes are now installed by default. It is not silently dropped:
  `libvirtd.nix` carries an assertion whose message is "the submodule has been
  removed", so writing it out of habit fails evaluation. `qemuOvmf` and
  `qemuOvmfPackage` are `mkRemovedOptionModule` alongside it.
- `virtualisation.libvirtd.allowedBridges` was written as `[ "virbr0" ]`. That
  is already its nixpkgs default, verbatim.
- `spice-gtk` was added to `environment.systemPackages` next to
  `virtualisation.spiceUSBRedirection.enable`, which installs `spice-gtk`
  itself for the polkit actions belonging to its setuid wrapper.

Only the first would have failed. The other two are the same class as the
`lib.mkIf (!pkgs.stdenv.isDarwin)` hand-restatement CLAUDE.md warns about under
"Platform support is derived": **config that agrees with the default is not
harmless, because it reads as a decision.** The duplicate `spice-gtk` was found
by evaluating the package-name list and noticing the same string twice —
`nix eval … environment.systemPackages --apply` with a filter, which takes
seconds and is worth doing after adding any module that installs things.

The general habit, since option churn in `virtualisation.*` is heavy: **read
the nixpkgs module, not the wiki.** The `mkRenamedOptionModule` /
`mkRemovedOptionModule` block near the top of one is a changelog of exactly the
options a stale guide will tell you to set.
