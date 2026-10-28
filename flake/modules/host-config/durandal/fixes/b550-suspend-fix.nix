# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    nixos = {
        # Stops durandal (Gigabyte B550M DS3H) waking again the instant it
        # suspends, by clearing PCI wakeup on both Starship/Matisse GPP
        # bridges (1022:1483).
        #
        # No longer "pending nixos-hardware" -- that PR landed. The same rule
        # ships upstream as nixosModules.gigabyte-b550, verified byte-identical
        # on 2026-08-14. Kept local on purpose: it is four lines, and an
        # upstream removal or rename would otherwise drop the fix silently on
        # an input bump. Don't import gigabyte-b550 as well; that just writes
        # the same rule twice.
        services.udev.extraRules = ''
        ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x1022", ATTR{device}=="0x1483", ATTR{power/wakeup}="disabled"
        '';
    };
}
