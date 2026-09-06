{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            # android-studio: IDE for Kotlin/Java Android app dev, bundles the
            # SDK manager, platform images, and the emulator. meta.platforms is
            # x86_64-linux only, so drop-unsupported-packages.nix drops this on
            # nire-lysithea (darwin) automatically -- no manual guard needed
            # (see skill nirepackages-platform-support). The emulator's
            # hardware acceleration also needs /dev/kvm access, which is the
            # `kvm` extraGroups entry in elly-user.nix, not anything here.
            home.packages = with pkgs; [
                android-studio
            ];
        };
}
