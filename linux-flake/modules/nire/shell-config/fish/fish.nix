
{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName} = {
        nixos = { pkgs, ... }: {
            environment.shells = with pkgs; [
                fish
            ];
            environment.pathsToLink = [
                "/share/fish"
            ];
            environment.systemPackages = with pkgs; [
                fishPlugins.fzf-fish
            ];
        }; 
        homeManager = { ... }: {
            programs.fish = {
                enable = true;
                interactiveShellInit = ''
                    function fish_prompt
                        starship prompt
                    end
                '';
                generateCompletions = true;
            };
        };
    };
}
