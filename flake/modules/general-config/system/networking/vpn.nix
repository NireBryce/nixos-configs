{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            # The daemon, not just the app: until 2026-09-26 this installed
            # `mullvad-vpn` into systemPackages with no service, so the GUI
            # had no daemon to talk to. The module now splits them --
            # `package` (default pkgs.mullvad) is the daemon + CLI, the GUI
            # is gui.*; pointing `package` at pkgs.mullvad-vpn fails its own
            # assertion. Installs both, so the old systemPackages line went.
            #
            # enableExcludeWrapper (default true) installs `mullvad-exclude`
            # SETUID ROOT, which lets anything running as any user put a
            # command outside the tunnel. Off: not used here, and a setuid
            # binary that exists to bypass the VPN is the wrong default.
            #
            # Idle until you connect -- no lockdown mode unless set in the
            # app. When connected, mullvad's firewall can drop tailnet
            # traffic; that's the app's "local network sharing" / split
            # tunnel settings, not anything declared here.
            #
            # State (/etc/mullvad-vpn: account, device, settings) survives
            # the /root wipe via mullvad-persist.nix.
            services.mullvad-vpn = {
                enable               = true;
                gui.enable           = true;
                enableExcludeWrapper = false;
            };
        };
}
