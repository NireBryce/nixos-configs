# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: {
            home.packages = with pkgs; [
                claude-code
            ];
    };
}
