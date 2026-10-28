# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    nixos = { pkgs, ... }: {
        # package summary: nix-output-monitor -- `nom`, progress display for nix builds
        environment.systemPackages = with pkgs; [
            nix-output-monitor # `nom` nix-output-monitor                  https://github.com/maralorn/nix-output-monitor
        ];
    };
}
