{
    ...
}:

{ den.aspects.dev-tools.nixos = 
{pkgs, ...}: 
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
