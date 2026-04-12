{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.nixos = { pkgs, ... }: {
        # Temporary B550 suspend fix pending nixos-hardware update
        services.udev.extraRules = ''
            ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x1022", ATTR{device}=="0x1483", ATTR{power/wakeup}="disabled"
        '';
    };
}
