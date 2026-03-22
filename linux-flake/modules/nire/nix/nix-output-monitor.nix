{ self, inputs, ...}:
{ flake.nixosModules.nix = 
{ pkgs, ... }:  
{
    environment.systemPackages = with pkgs; [
        nix-output-monitor          # `nom` nix-output-monitor                  https://github.com/maralorn/nix-output-monitor
    ];
}
;}
