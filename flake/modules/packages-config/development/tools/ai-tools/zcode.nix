# Module file: named after this file; why it looks this way: wiki/module-files.md
{ inputs, ... }:
{
    homeManager = { pkgs, ... }: {
        home.packages = with pkgs; [
            # pkgs.system is the deprecated alias of this (2026-09-09, issue #233)
            inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.zcode
        ];
    };
}
