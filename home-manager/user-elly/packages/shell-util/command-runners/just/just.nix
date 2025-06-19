{ ... }:
{
    description = "just - justfile runner";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        just
    ];
    in
    {
        home.file = {
            "./.justfile"         .source = ./config/.just/.justfile;
            "./.just/.justfile"   .source = ./config/.justfile;
            "./.just"             .source = ./config;
        };

        home.packages = packageList;
    };
}
