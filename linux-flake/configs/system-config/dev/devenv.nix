{
    lib,
    config,
    ...
}:
let
    enabled = builtins.elem "develop" (config.my.roles or []);
in
{
    flake.modules.nixos.develop = { pkgs, ... }: {
        config = lib.mkIf enabled {
            nix.settings = {
                substituters = [ "https://devenv.cachix.org/" ];
                trusted-public-keys = [ "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=" ];
            };
            environment.systemPackages = with pkgs; [
                devenv
            ];

            # cachix.enable = false; # disable cachix caching
        };
    };
}
