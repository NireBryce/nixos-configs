# Turns nire-installer's `system.build.isoImage` into a flake package, so
# `nix build .#liveusb-testbed-installer` (or `just liveusb`) produces
# something `dd`-able to a USB stick without anyone needing to know the
# nixosConfigurations attribute path by heart.
#
# Lives in nireHost/installer/ next to installer-configuration.nix, the
# script and the doc -- see that file's header for why the whole feature is
# grouped in one folder rather than split the way checks.nix/hosts.nix are.
# Same as those two, it is an entry point rather than a category member: it
# declares no flake.modules.<class> attribute at all, only `perSystem`, so
# there is nothing for any dirsAsCategory.nix to collect even if one existed
# above it -- and neither nireHost/ nor nireHost/installer/ has one anyway.
{ config, lib, ... }:
{
    perSystem = { system, ... }:
    {
        # x86_64-linux only, same filter checks.nix uses for host toplevels --
        # nire-installer is an x86_64-linux nixosConfiguration, and there is no
        # remote builder or binfmt from aarch64-darwin to build it with. The
        # `packages` key itself stays present on every system (empty on
        # darwin) rather than the whole perSystem result being conditional --
        # a perSystem module returning different top-level keys per system
        # was enough to make flake-parts' own `formatter` output heuristic
        # fail with "could not determine statically that no formatter is
        # defined for *all* systems", on a file that sets no formatter at all.
        packages = lib.optionalAttrs (system == "x86_64-linux") {
            liveusb-testbed-installer =
                config.flake.nixosConfigurations.nire-installer.config.system.build.isoImage;
        };
    };
}
