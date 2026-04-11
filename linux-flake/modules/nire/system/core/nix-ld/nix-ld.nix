{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.system._.${moduleName}.nixos = {
        # description = "nix-ld, needed for VSCode remote connection, etc";
        programs.nix-ld.enable = lib.mkDefault true;
    };
}
