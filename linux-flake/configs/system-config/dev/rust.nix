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
            environment.systemPackages = with pkgs; [
                cargo
                rustc
                rustup
                rustfmt
                clippy
                rust-analyzer
            ];
        };
    };
}

    
