{ 
    perSystem = {pkgs, lib, inputs, ...}: # TODO: remove need for `inputs`, try `'self?`
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
  flake.modules.nixos.${moduleName} = {
        programs.vscode = {
          enable = true;
          package = pkgs.vscode-fhs;
        };
        
        programs.nix-ld.enable = true; # Needed for VSCode remote connection, etc
        environment.sessionVariables.NIXOS_OZONE_WL = "1"; # TODO: this is erroring benignly
        nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ]; # https://discourse.nixos.org/t/vs-code-and-nix-ide-newbie-problems/51385/5
      };
  };
}
