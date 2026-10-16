# Module file: named after this file; why it looks this way: wiki/module-files.md
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
