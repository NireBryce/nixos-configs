# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: {
            # bubblewrap: unprivileged sandboxing tool. Filed here, not
            # linux-utils/, because it's here for Claude Code's sandbox
            # (claude.nix), which needs `bwrap` and `socat` on PATH on Linux;
            # socat is linux-utils/linux-networking/socat.nix. Linux-only,
            # so darwin drops it automatically (drop-unsupported-packages.nix).
            home.packages = with pkgs; [
                bubblewrap
            ];
    };
}
