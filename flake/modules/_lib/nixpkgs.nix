# The fleet's nixpkgs configuration, written once. Hosts take it as
# `nixpkgs.config` (general-config/nix/nix-settings/basic-nix-settings.nix and
# hardware-config/hardware/firmware/firmware-all.nix); perSystem's `pkgs`
# is built from it (nixpkgs.nix), so a check or dev shell sees what a host
# sees. Add a key here, not in a module. Takes the `{ lib }` argument the other
# `_lib/` files do, and ignores it.
_:
{
    config = {
        allowUnfree = true;
    };
}
