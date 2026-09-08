{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, lib, ... }:
            # cmux (meta.platforms = [ "aarch64-darwin" ]) is the mirror image of
            # the usual case: drop-unsupported-packages.nix's meta.platforms
            # filter only runs on darwin -- on Linux it's a no-op by design (see
            # CLAUDE.md / skill nirepackages-platform-support), so a darwin-only
            # package left unguarded fails `nix flake check`/the toplevel build
            # on every Linux host as soon as buildEnv forces its derivation.
            # lysithea is the only darwin host, so this guard is exact, not just
            # convenient -- there's no case where cmux should install elsewhere.
            lib.mkIf pkgs.stdenv.isDarwin {
                # cmux: macOS-native terminal built on Ghostty for AI coding agents
                home.packages = with pkgs; [
                    cmux
                ];
        };
}
