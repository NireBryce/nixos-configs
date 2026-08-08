{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { pkgs, ... }: {
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
  
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
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
}
