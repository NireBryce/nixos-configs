{ lib, inputs, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            home.packages = with pkgs; [
                inputs.llm-agents.packages.${pkgs.system}.zcode
            ];
        };
}
