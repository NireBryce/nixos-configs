# dirs-as-categories: the module is named after this file; its categories are the folders above it
{ inputs, ... }:
{
    homeManager = { pkgs, ... }: {
        home.packages = with pkgs; [
            # pkgs.system is the deprecated alias of this (2026-09-09, issue #233)
            inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.zcode
        ];
    };
}
