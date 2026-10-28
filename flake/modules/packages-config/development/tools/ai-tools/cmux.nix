# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    homeManager = { pkgs, lib, ... }:
        # cmux (meta.platforms = [ "aarch64-darwin" ]) is the mirror image of
        # the usual case: drop-unsupported-packages.nix's meta.platforms
        # filter only runs on darwin -- on Linux it's a no-op by design (see
        # CLAUDE.md / skill package-platform-support), so a darwin-only
        # package left unguarded fails `nix flake check`/the toplevel build
        # on every Linux host as soon as buildEnv forces its derivation.
        # lysithea is the only darwin host, so this guard is exact, not just
        # convenient -- there's no case where cmux should install elsewhere.
        lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
            # package summary: cmux -- macOS terminal built on Ghostty for AI coding agents
            # cmux: macOS-native terminal built on Ghostty for AI coding agents
            home.packages = with pkgs; [
                cmux
            ];
    };
}
