# Tailscale, as an actual service rather than just the CLI on PATH.
#
# vpn.nix had `tailscale` in environment.systemPackages with `# TODO: move to
# module` next to it, and that was the whole of it: the binary existed, nothing
# ran it. `systemctl is-enabled tailscaled` answered "not-found" -- no unit, not
# a stopped one. services.tailscale.enable is what actually generates it, and it
# installs the CLI itself (`environment.systemPackages = [ cfg.package ]`, in
# nixos/modules/services/networking/tailscale.nix), so vpn.nix's copy was dropped
# in the same change rather than left to shadow this one.
#
# networking.nix carried two `# TODO: move to tailscale-autoconnect` markers, for
# a module that was never written. Upstream now covers what they were reaching
# for: `openFirewall` opens the daemon's UDP port (the commented-out
# `config.services.tailscale.port` line there), and an autoconnect unit comes
# free with `authKeyFile` if it is ever wanted. Same shape as the
# handheld-daemon shim that turned out to be unnecessary -- check upstream before
# hand-writing the integration.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            services.tailscale = {
                enable = true;

                # Opens the daemon's own UDP port. networking.nix already has
                # `tailscale0` in trustedInterfaces, which is the other half --
                # that covers traffic arriving over the tunnel, this covers the
                # tunnel being established.
                openFirewall = true;

                # authKeyFile is deliberately NOT set, though secrets.yaml does
                # carry an (undeclared, unused) `tailscale_key`. Tailscale auth
                # keys expire -- 90 days maximum, and that one predates the
                # flake-parts port -- so wiring it in would most likely mean a
                # tailscaled-autoconnect.service that fails on every boot rather
                # than a machine that authenticates itself. With the state
                # directory persisted below, `sudo tailscale up` once is enough
                # and survives reboots. To revisit: mint a fresh key, add
                # `sops.secrets.tailscale_key` in system/secrets/sops.nix
                # (nothing declares it today), and point authKeyFile at
                # config.sops.secrets.tailscale_key.path.
            };

            # WITHOUT THIS, TAILSCALE NEEDS RE-AUTHENTICATING ON EVERY BOOT.
            # Node identity lives in /var/lib/tailscale/tailscaled.state, and
            # both hosts importing this roll `/` back to root-blank in initrd --
            # so anything under /var/lib that is not persisted is gone by the
            # time the daemon starts. See impermanence/WARN-impermanence.nix.
            #
            # Declared here rather than in WARN-impermanence.nix's own list,
            # following the convention that file states: persistence for state
            # that only matters to one thing lives next to what generates it,
            # the way jovian.nix declares /etc/hhd. `directories` is `listOf`,
            # so the entries concatenate.
            #
            # This assumes the host also imports `impermanence`, which both
            # Linux hosts do. A future host taking `system` WITHOUT it would hit
            # an option-does-not-exist error here and would need this guarded,
            # not just deleted -- same caveat jovian.nix records for its own.
            environment.persistence."/persist".directories = [ "/var/lib/tailscale" ];
        };
}
