{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perUser {
    homeManager = { pkgs, ... }: {
    # # description = "piper - logitech/razer graphical mouse manager https://github.com/soxoj/piper";
    home.packages = with pkgs; [
      piper
    ];
  };
  };
}
