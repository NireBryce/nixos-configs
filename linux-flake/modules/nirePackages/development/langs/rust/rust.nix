{ lib, ... }:
    let
      moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in
    {
        flake.modules.nixos.${moduleName} = { pkgs, ... }: {
            environment.systemPackages = with pkgs; [
                cargo
                rustc
                rustup
                rustfmt
                clippy
                rust-analyzer
            ];
        };
}
