# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{ inputs, ... }:
{
    homeManager = { pkgs, ... }: {
        home.packages = with pkgs; [
            # pkgs.system is the deprecated alias of this (2026-09-09, issue #233)
            inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.zcode
        ];
    };
}
