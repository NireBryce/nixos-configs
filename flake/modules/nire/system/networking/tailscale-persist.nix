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
# This assumes the host also imports `impermanence`, which both Linux hosts do.
# A future host taking `system` WITHOUT it would hit an option-does-not-exist
# error here and would need this guarded, not just deleted -- same caveat
# jovian-persist.nix records for its own.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            environment.persistence."/persist".directories = [ "/var/lib/tailscale" ];
        };
}
