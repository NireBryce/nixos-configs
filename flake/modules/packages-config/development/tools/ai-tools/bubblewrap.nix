# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    homeManager = { pkgs, ... }: {
            # package summary: bubblewrap -- unprivileged sandboxing tool (`bwrap`)
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
