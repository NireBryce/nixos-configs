# Unattended install of nire-testbed: a systemd service that mounts the
# real disk's already-known partitions and runs `nixos-install --flake`
# with nobody driving Calamares or a terminal, plus (optionally) wifi
# credentials to get on the network with nobody typing an `nmtui` password
# either. Merges into flake.modules.nixos.installerConfiguration, same
# mechanism as installer-calamares.nix -- see that file's header for why
# that's a deliberate merge, not a typo, and what `just modules` can't see
# about it.
#
# Exists alongside, not instead of, the Calamares and hand-run paths in
# liveusb-installer.md: none of the three has been confirmed against real
# hardware, and this one in particular has the least room for a human to
# notice something's wrong mid-install, being the one built for nobody to be
# watching. See that doc for the full picture and which path to reach for
# when.
{ ... }:
{
    flake.modules.nixos.installerConfiguration = { lib, pkgs, ... }:
    let
        # Read only via `nix build --impure` (build-liveusb.sh's own
        # invocation) -- ordinary `nix eval`/`nix flake check`/`just modules`
        # run in Nix's default pure-eval mode, where builtins.getEnv always
        # returns "" rather than erroring (Nix manual, restricted eval), so
        # hasWifiCreds below is simply false and this whole block is a no-op
        # for every verification command already in use in this repo. Only
        # an explicit `--impure` build (and the env vars actually set) turns
        # it on.
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

        # The exact UUIDs hardware-testbed.nix already carries for this
        # disk (real, read off the machine -- see that file's own header
        # and history note). Mount-by-UUID is the safety mechanism here,
        # not a formality: if the disk doesn't have these exact partitions
        # -- wrong machine, a wipe, a repartition -- the mount just fails
        # and the script below refuses to guess or partition anything. It
        # can never touch the wrong disk the way a blind `parted /dev/sda`
        # could.
        rootUuid = "298d1ce7-3fb9-4918-b77c-21d419ccf62a";
        bootUuid = "DED7-8FEF";

        autoinstallScript = pkgs.writeShellScript "autoinstall-testbed" ''
            set -euo pipefail

            root_dev=/dev/disk/by-uuid/${rootUuid}
            boot_dev=/dev/disk/by-uuid/${bootUuid}

            if [ ! -e "$root_dev" ] || [ ! -e "$boot_dev" ]; then
                echo "autoinstall-testbed: expected partitions not found (root=${rootUuid} boot=${bootUuid})." >&2
                echo "autoinstall-testbed: refusing to guess or partition anything -- not installing." >&2
                echo "autoinstall-testbed: this is not the disk hardware-testbed.nix was written for, or it was reformatted. See liveusb-installer.md." >&2
                exit 1
            fi

            echo "autoinstall-testbed: found the expected partitions. Installing in 10s."
            echo "autoinstall-testbed: to abort, from another session: systemctl stop autoinstall-testbed"
            sleep 10

            mkdir -p /mnt
            mount "$root_dev" /mnt
            mkdir -p /mnt/boot
            mount "$boot_dev" /mnt/boot

            echo "autoinstall-testbed: mounted. Running nixos-install --flake -- this can take a while, watch with: journalctl -u autoinstall-testbed -f"
            nixos-install \
                --root /mnt \
                --flake path:/etc/nixos-configs#nire-testbed \
                --no-root-passwd

            umount -R /mnt || true

            echo "autoinstall-testbed: install finished. Reboot manually when ready: 'reboot'."
            echo "autoinstall-testbed: deliberately NOT auto-rebooting -- one last chance to notice something's wrong before committing to it."
        '';
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

        systemd.services.autoinstall-testbed = {
            description = "Unattended nixos-install of nire-testbed onto its already-partitioned disk";
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
                # Keeps `systemctl status autoinstall-testbed` showing
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
