# This is a dirs-as-categories module, which means it creates a flake-parts
# module that derives its name from its filename minus the .nix suffix, whose
# category module is the name of the folder it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    homeManager = { pkgs, ... }: {
        # restic-compatible client with an interactive TUI (`rustic
        # snapshots -i`) for browsing/restoring a repository --
        # reads/writes the same repo format services.restic writes on
        # nire-cube. Uses its own RUSTIC_* env vars, not restic's
        # RESTIC_* ones -- see wiki/homelab/rustic.md.
        home.packages = with pkgs; [
            rustic
        ];
    };
}
