# Unattended install of a target host: a systemd service that mounts the
# real disk's already-known partitions and runs `nixos-install --flake`
# with nobody driving Calamares or a terminal, plus (optionally) wifi
# credentials to get on the network with nobody typing an `nmtui` password
# either. Merges into flake.modules.nixos.installerConfiguration, same
# mechanism as installer-calamares.nix -- see that file's header for why
# that's a deliberate merge, not a typo, and what `just modules` can't see
# about it.
#
# Renamed from installer-autoinstall-testbed.nix 2026-08-22, when nire-testbed
# (the host this was originally written for and the only one it ever pointed
# at) was removed: nothing about the mechanism was actually testbed-specific,
# so it was generalized rather than deleted. The target host, and the disk's
# partition UUIDs, are now chosen at image-build time the same way the wifi
# credentials below already were -- see NIRE_INSTALLER_TARGET_HOST,
# NIRE_INSTALLER_ROOT_UUID, NIRE_INSTALLER_BOOT_UUID and build-liveusb.sh.
#
# Exists alongside, not instead of, the Calamares and hand-run paths in
# liveusb-installer.md: none of the three has been confirmed against real
# hardware since this generalization, and this one in particular has the
# least room for a human to notice something's wrong mid-install, being the
# one built for nobody to be watching. See that doc for the full picture and
# which path to reach for when.
{ ... }:
{
    flake.modules.nixos.installerConfiguration = { lib, pkgs, ... }:
    let
        # Read only via `nix build --impure` (build-liveusb.sh's own
        # invocation) -- ordinary `nix eval`/`nix flake check`/`just modules`
        # run in Nix's default pure-eval mode, where builtins.getEnv always
        # returns "" rather than erroring (Nix manual, restricted eval), so
        # hasWifiCreds/hasAutoinstall below are simply false and this whole
        # file is a no-op for every verification command already in use in
        # this repo. Only an explicit `--impure` build (and the env vars
        # actually set) turns any of it on.
        #
        # Deliberately NOT committed anywhere in this repo, per the reason
        # this file exists at all: build-liveusb.sh prompts for these
        # interactively at build time and passes them through as env vars,
        # so a wifi password never touches git history. It DOES end up
        # embedded in plaintext in the built ISO's Nix store regardless
        # (there is no other way for an unattended live image to associate
        # with a secured network with nobody present to type anything) --
        # treat a built image with credentials baked in as sensitive: don't
        # publish it, and rotate the wifi password afterward if that
        # matters to you.
        wifiSsid     = builtins.getEnv "NIRE_INSTALLER_WIFI_SSID";
        wifiPassword = builtins.getEnv "NIRE_INSTALLER_WIFI_PASSWORD";
        hasWifiCreds = wifiSsid != "" && wifiPassword != "";

        # Which flake attr to install, and the exact partition UUIDs of the
        # disk it's already been partitioned on -- all three read the same
        # way as the wifi credentials above, and all three are required
        # together for this feature to do anything (see hasAutoinstall).
        # Mount-by-UUID is the safety mechanism here, not a formality: if the
        # disk doesn't have these exact partitions -- wrong machine, a wipe,
        # a repartition -- the mount just fails and the script below refuses
        # to guess or partition anything. It can never touch the wrong disk
        # the way a blind `parted /dev/sda` could.
        targetFlakeAttr = builtins.getEnv "NIRE_INSTALLER_TARGET_HOST";
        rootUuid        = builtins.getEnv "NIRE_INSTALLER_ROOT_UUID";
        bootUuid        = builtins.getEnv "NIRE_INSTALLER_BOOT_UUID";
        hasAutoinstall  = targetFlakeAttr != "" && rootUuid != "" && bootUuid != "";

        # Kept as a real .sh file (config/autoinstall.sh) rather than an
        # inline '' ... '' string -- installer-checks.nix shellchecks it
        # directly, which an inline string can't be (shellcheck needs a real
        # file, and disagrees with itself about heredoc-embedded Nix
        # interpolation splicing arbitrary text into the middle of a shell
        # token). @rootUuid@/@bootUuid@/@targetFlakeAttr@ substituted with
        # lib.replaceStrings, not Nix string interpolation, for the same
        # reason -- an inline ${rootUuid} would make the source file invalid
        # shell on its own.
        autoinstallScript = pkgs.writeShellScript "autoinstall"
            (lib.replaceStrings
                [ "@rootUuid@" "@bootUuid@" "@targetFlakeAttr@" ]
                [ rootUuid    bootUuid    targetFlakeAttr    ]
                (builtins.readFile ./config/autoinstall.sh));
    in {
        # Only materializes with real credentials present (see hasWifiCreds
        # above) -- otherwise this is an empty attrset and wifi stays
        # exactly as installer-configuration.nix already has it
        # (NetworkManager on, nothing auto-connects, nmtui by hand).
        networking.networkmanager.ensureProfiles.profiles = lib.mkIf hasWifiCreds {
            "autoinstall-wifi" = {
                connection = {
                    id = "autoinstall-wifi";
                    type = "wifi";
                    autoconnect = true;
                };
                wifi = {
                    ssid = wifiSsid;
                    mode = "infrastructure";
                };
                wifi-security = {
                    key-mgmt = "wpa-psk";
                    psk = wifiPassword;
                };
                ipv4.method = "auto";
                ipv6.method = "auto";
            };
        };

        # Only materializes with a target host and both UUIDs actually set
        # (see hasAutoinstall above) -- otherwise this unit doesn't exist at
        # all, rather than existing and failing loudly on every boot of an
        # image nobody meant to run it unattended.
        systemd.services.autoinstall = lib.mkIf hasAutoinstall {
            description = "Unattended nixos-install of the configured target host onto its already-partitioned disk";
            # network-online.target, not just network.target: nixos-install
            # needs to actually reach the binary cache, not merely have an
            # interface configured -- same reason any real host's
            # network-dependent services wait on this rather than the
            # weaker target.
            after    = [ "network-online.target" ];
            wants    = [ "network-online.target" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
                Type = "oneshot";
                # Keeps `systemctl status autoinstall` showing
                # success/failure after the oneshot script exits, instead of
                # reverting to "inactive (dead)" and losing that at a
                # glance -- useful over SSH, where nobody's watching the
                # console output live.
                RemainAfterExit = true;
                ExecStart = "${autoinstallScript}";
            };
        };
    };
}
