{
  inputs,
  lib,
  ...
}:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
  nire.moduleStore._.${moduleName}.nixos =
    { pkgs, ... }:
    {
      programs.vscode = {
        enable = true;
        package = pkgs.vscode-fhs;
      };

      # vscode settings
      environment.sessionVariables.NIXOS_OZONE_WL = "1"; # TODO: this is erroring benignly
      environment.systemPackages = with pkgs; [
        nixd # nix LSP
        nixfmt
        nixpkgs-fmt
      ];

      nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ]; # https://discourse.nixos.org/t/vs-code-and-nix-ide-newbie-problems/51385/5

      programs.nix-ld.enable = true; # Needed for VSCode remote connection, etc
    };
}
