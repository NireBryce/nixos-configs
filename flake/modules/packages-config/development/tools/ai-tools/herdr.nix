# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: {
            # # description = "herdr: agent multiplexer that lives in your terminal"
            home.packages = with pkgs; [
                herdr
            ];
    };
}
