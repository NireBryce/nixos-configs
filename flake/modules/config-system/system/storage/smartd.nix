# smartmontools (smartctl/smartd): general-purpose SMART/NVMe health and
# wear monitoring, for every NixOS host regardless of desktop environment.
# The KDE-specific half of this -- a systray applet on top of the same
# data -- is kde-base.nix's plasma-disks entry, not here.
#
# smartmontools is put in `environment.systemPackages` rather than pulled in
# implicitly through `services.smartd` (which references
# `${pkgs.smartmontools}/sbin/smartd` directly and would work without this):
# plasma-disks' kded-smart-helper shells out to a bare `smartctl` and is
# itself a system D-Bus service (org.kde.kded.smart.service), not a home-manager
# package, so it needs smartctl on the *system* PATH
# (/run/current-system/sw/bin) to find it at all -- a home-manager-only
# install would leave that service silently unable to query anything.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { pkgs, ... }: {
            environment.systemPackages = with pkgs; [
                smartmontools # smartctl/smartd -- https://www.smartmontools.org/
            ];

            services.smartd = {
                enable    = true; # polls all autodetected devices, warns on
                                   # prefail/failure attributes and errors --
                                   # NixOS module's own `-a` default.
                autodetect = true;

                defaults.monitored =
                    "-a -o on -s (S/../.././02|L/../../7/04)";
                    # `-a`: full monitoring (as the plain default already gives).
                    # `-o on`: SMART Automatic Offline Testing.
                    # `-s ...`: schedule short self-tests daily at 02:00 and a
                    # long self-test weekly (Sundays) at 04:00 -- straight from
                    # `man 5 smartd.conf`'s own example. Self-tests are
                    # non-destructive reads; this is what actually exercises
                    # wear/surface detection instead of only reading counters
                    # passively.

                # notifications.wall.enable is already the module default
                # (true); notifications.x11.enable already defaults to
                # config.services.xserver.enable, which kde-base.nix sets on
                # every desktop host here -- no override needed for either.
            };
        };
}
