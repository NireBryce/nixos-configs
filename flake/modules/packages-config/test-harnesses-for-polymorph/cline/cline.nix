# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    nixos = { pkgs, ... }: {
        # package summary: cline -- autonomous coding agent CLI for the terminal
        # nixos class, not homeManager: the category is imported by
        # nire-durandal only, and elly-home-manager is shared by every host.
        environment.systemPackages = with pkgs; [
            cline
        ];
    };
}
