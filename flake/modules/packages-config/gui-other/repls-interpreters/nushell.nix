# This is a dirs-as-categories module, which means it creates a flake-parts
# module that derives its name from its filename minus the .nix suffix, whose
# category module is the name of the folder it belongs to.
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
