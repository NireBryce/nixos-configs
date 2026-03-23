{ self, inputs, ...}:
{ flake.modules.nixos.dev-tools =
{ pkgs, ...}: 
{
    environment.systemPackages = with pkgs; [
        cargo
        rustc
        rustup
        rustfmt
        clippy
        rust-analyzer
    ];
}
;}
