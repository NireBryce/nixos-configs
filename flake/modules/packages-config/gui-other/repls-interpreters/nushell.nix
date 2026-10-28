# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{ 
    homeManager = { pkgs, ... }: {
        # nushell - the next generation shell
        # hint: nushell -c for tabular display in any shell
        home.packages = with pkgs; [
            nushell
        ];
    };
}
