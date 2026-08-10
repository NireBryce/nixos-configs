{ lib, ... }:

    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = {
            # # description = "Like raycast for linux";
            programs.vicinae = {
                enable = true;
                systemd = {
                    enable = true;
                    autoStart = true;

                    # NOT graphical-session.target, which is the module default
                    # and is reached too early here. Timeline from the first
                    # boot of this branch, 2026-08-10:
                    #
                    #   17:48:58  Reached target Main User Target
                    #   17:48:59  vicinae starts, 1st attempt
                    #   17:49:04/09/14/20   attempts 2-5, Restart=always at 5s
                    #   17:49:25  sddm finally launches startplasma-wayland
                    #
                    # So all five attempts, and the whole start-limit budget,
                    # were spent *before the compositor existed*. Each one found
                    # no WAYLAND_DISPLAY, fell back to the xcb Qt platform
                    # plugin, failed to connect and called qFatal -- and each
                    # coredump launched a DrKonqi that is itself a Qt app with
                    # the same problem, which is where 103 drkonqi crashes in
                    # one boot came from.
                    #
                    # plasma-workspace.target is only reached once Plasma is
                    # actually up, by which point the session has exported
                    # WAYLAND_DISPLAY into the user manager. Checked on the
                    # running system: DISPLAY=:0 and WAYLAND_DISPLAY=wayland-0
                    # are both present in `systemctl --user show-environment`
                    # now -- they simply were not yet at 17:48:59.
                    #
                    # A second handheld with a different desktop would need its
                    # own value here; this one is Plasma-specific.
                    target = "plasma-workspace.target";
                };
            };
        };
}
