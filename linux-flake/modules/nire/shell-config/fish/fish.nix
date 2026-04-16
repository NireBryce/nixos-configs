{ den, lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perHost {
    nixos =
      { pkgs, ... }:
      {
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
  };
  den.aspects.moduleStore._.${moduleName} = den.lib.perUser {
    homeManager =
      { ... }:
      {
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
