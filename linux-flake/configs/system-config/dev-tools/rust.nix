{
    ...
}:

{ den.aspects.nixos.provides.dev-tools = 
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
