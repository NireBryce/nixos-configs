{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
  aspectChain = den.aspects.moduleStore._.${moduleName};
in
{
  ${aspectChain} = den.lib.perUser {
    homeManager = { pkgs, ... }: {
    # # description = "piper - logitech/razer graphical mouse manager https://github.com/soxoj/piper";
    home.packages = with pkgs; [
      piper
    ];
  };
  };
}
