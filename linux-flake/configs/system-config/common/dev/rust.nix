{ pkgs, ... }:
let 
    packageList = with pkgs; [
        cargo
        rustc
        # rustup
        rustfmt
        clippy
        rust-analyzer
    ];
in
{
    environment.systemPackages = packageList;
}

    
