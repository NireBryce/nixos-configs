{ pkgs, ... }:
let 
    packageList = with pkgs; [
        cargo
        rustc
        rustfmt
        clippy
        rust-analyzer
    ];
in
{
    home.packages = packageList;
}

    
