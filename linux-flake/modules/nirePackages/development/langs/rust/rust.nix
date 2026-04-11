{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.development._.${moduleName}.nixos = {
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
