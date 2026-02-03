# desc = "";
{ flake.modules.homeManager.common.nix-settings =
{ ... }:

{
    nixpkgs.config = {
        allowUnfree          =     true;            # Disable if you don't want unfree packages
        allowUnfreePredicate = (_: true);           # Workaround for https://github.com/nix-community/home-manager/issues/2942
    };
}
;}
