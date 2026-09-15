{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            # just - justfile runner
            #
            # `just -g`/`--global-justfile` is what reads this: confirmed by
            # straceing it (2026-08-22, nire-durandal, just 1.57.0) -- it opens
            # ~/.justfile directly, not ~/.config/just/justfile (the path just's
            # own docs imply) and not ~/.just/.justfile. This module used to also
            # place a ~/.just/ directory (and a redundant copy of the same file
            # inside it) on the theory that just might look there; it never did,
            # on any version this repo has run. Dropped 2026-08-22 -- see
            # hm-collisions.sh's history note for the false-positive collision
            # that redundancy used to cause.
            home.file."./.justfile".source = ./config/.justfile;

            home.packages = with pkgs; [
                just
            ];
        };
}
