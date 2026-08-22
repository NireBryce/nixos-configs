# The persistence half of tailscale.nix. Split out 2026-08-14; until then this
# was the last block of that file.
#
# WITHOUT THIS, TAILSCALE NEEDS RE-AUTHENTICATING ON EVERY BOOT. Node identity
# lives in /var/lib/tailscale/tailscaled.state, and both hosts importing this
# roll `/` back to root-blank in initrd -- so anything under /var/lib that is
# not persisted is gone by the time the daemon starts. See
# impermanence/root-rollback/WARN-impermanence.nix.
#
# Filed beside tailscale.nix rather than in the impermanence category, following
# the convention WARN-impermanence.nix states: persistence for state that only
# matters to one thing lives next to what generates it, the way
# jovian-persist.nix does for /etc/hhd. Being a sibling also means the same
# category collects it, so it reaches exactly the hosts tailscale.nix reaches --
# filing it under nire/impermanence/ instead would change which hosts get it.
#
# `directories` is `listOf`, so the entries concatenate with
# WARN-impermanence.nix's own list rather than overriding it.
#
# GUARDED, 2026-08-14: this used to assume every host taking `system` also
# imports `impermanence`, true of both hosts that existed then. The first host
# added without it (originally nire-testbed, since removed; nire-cube is the
# current example) does not -- persistent root, nothing wipes
# /var/lib/tailscale -- and this entry would have been pure overhead for it: a
# same-filesystem bind mount
# rescuing state from a wipe that never happens, plus a real side effect,
# impermanence's own "Neither /var/lib/nixos nor any of its parents are
# persisted" warning, which fires the moment ANY environment.persistence entry
# exists without /var/lib/nixos alongside it (nixos.nix:608-610 in the
# impermanence flake). Wrong warning for a host with no wipe to worry about.
#
# `environment.persistence` itself is declared for every NixOS host regardless
# -- see nire/system/impermanence/declare-persistence-option.nix -- so this
# module no longer risks an option-does-not-exist error either way. What it
# guards now is a non-impermanence host getting an entry, and the warning, for
# no reason.
#
# Gated on boot.initrd.systemd.services ? restore-root, the same signal
# invariants.nix uses to mean "this host actually opted into impermanence" --
# see that file's "OPT-IN: HOSTS WITHOUT IMPERMANENCE ARE EXEMPT" header note
# for why that specific signal and not something else.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { config, lib, ... }:
            lib.mkIf (config.boot.initrd.systemd.services ? restore-root) {
                environment.persistence."/persist".directories = [ "/var/lib/tailscale" ];
            };
}
