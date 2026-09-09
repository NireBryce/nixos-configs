{ lib, inputs, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            home.packages = with pkgs; [
                # pkgs.system is the deprecated alias of this (2026-09-09, issue #233)
                inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.zcode
            ];
        };
}
