# devenv from nixpkgs (built by Hydra, served from cache.nixos.org).
#
# No devenv.cachix.org substituter. It used to sit here with its key in
# nix.settings.trusted-public-keys, which is daemon-wide: a trusted key can
# serve ANY store path the daemon asks that cache for, not just devenv's, so
# every host's whole closure trusted one third-party signing key. What it
# bought was prebuilt devenv-shell dependencies; without it those come from
# cache.nixos.org or build locally. Removed 2026-09-27.
#
# devenv (2.3.1) still requests its cachix caches per run, as
# extra-substituters; trusted-users is root-only, so the daemon ignores that
# with a "not a trusted user" warning -- no failure (devenv-core's
# detect_missing_caches has no callers). The same goes for any per-project
# cache in devenv.yaml or a flake's nixConfig: getting one back means
# trusting its key daemon-wide here again.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { pkgs, ... }: {
            environment.systemPackages = with pkgs; [
                devenv
            ];
        };
}
