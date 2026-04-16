{ den, lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
  aspectChain = den.aspects.moduleStore._.${moduleName};
in
{
  ${aspectChain} = den.lib.perUser { 
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
  };

  ${aspectChain} = den.lib.perHost { 
    nixos =
    { inputs, ... }:
    {
      # https://github.com/nix-community/nixd/blob/main/nixd/docs/configuration.md
      # set $NIX_PATH env to your flake input. 
      # maybe lets things expecting channels work better
      nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
      
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
