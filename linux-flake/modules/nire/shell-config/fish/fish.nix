
{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.shell-config._.${moduleName} = {
        nixos = {
            environment.shells = with pkgs; [
                fish
            ];
        }; 
        homeManager = { 
            programs.fish = {
                enable = true;
                interactiveShellInit = ''
                    function fish_prompt
                        starship prompt
                    end
                '';
                generateCompletions = true;
            };
            environment.pathsToLink = [
                "/share/fish"
            ];
            environment.systemPackages = with pkgs; [
                fishPlugins.fzf-fish
            ];
        };
    };
}
