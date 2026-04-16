{ lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
  den.aspects.moduleStore._.${moduleName} = {
    homeManager =
      { ... }:
      {
        nixpkgs.config = {
          allowUnfree = true; # Disable if you don't want unfree packages
          allowUnfreePredicate = (_: true); # Workaround for https://github.com/nix-community/home-manager/issues/2942
        };
        nix.extraOptions = "experimental-features = nix-command flakes";
        nix.settings = {
            trusted-users = [ "root" ];
            experimental-features = [
                # duplicated in extraOptions?
                "nix-command"
                "flakes"
            ];
        }; 
      };

      

    nixos =
      { ... }:
      {
        nix.extraOptions = "experimental-features = 'nix-command flakes'";
        nix.settings = {
          trusted-users = [ "root" ];
          experimental-features = [
            # duplicated in extraOptions?
            "nix-command"
            "flakes"
          ];
        };

        # FIX: `comma` fix https://github.com/nix-community/comma/issues/43 (25.12.01)
        # make nix-index not use channels https://github.com/nix-community/nix-index/issues/167
        nix.channel.enable = false;

        nixpkgs.config.allowUnfree = true;

      };
  };
}
