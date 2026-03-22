{ self, inputs, ...}:
{ flake.nixosModules.dev-tools =
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
