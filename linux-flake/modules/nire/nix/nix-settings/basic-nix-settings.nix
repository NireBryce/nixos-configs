{ lib, inputs, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
    
        flake.modules.homeManager.${moduleName} = {
            # `nixpkgs.config` cannot be set here. Home Manager is NixOS-managed
            # with useGlobalPkgs, which makes it reject every `nixpkgs.*` option
            # outright rather than ignore it. allowUnfree therefore comes from the
            # nixos module below, which applies to the same pkgs instance.
            #
            # This also drops the `allowUnfreePredicate = (_: true)` workaround for
            # home-manager issue #2942 that used to sit here. If unfree packages
            # start failing in home config, that is the first thing to look at.

            # nix.extraOptions = "experimental-features = nix-command flakes";
            # nix.settings = {
            #     trusted-users = [ "root" ];
            #     experimental-features = [
            #         # duplicated in extraOptions?
            #         "nix-command"
            #         "flakes"
            #     ];
            # }; 
        };

        flake.modules.nixos.${moduleName} = {
            # https://github.com/nix-community/nixd/blob/main/nixd/docs/configuration.md
            # set $NIX_PATH env to your flake input. 
            # maybe lets things expecting channels work better
            nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
            
            # nix.extraOptions = "experimental-features = 'nix-command flakes'";
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
}
