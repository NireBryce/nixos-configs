{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = {
            # # description = "espanso is a text expansion tool that turns a trigger phrase into text";

            # TODO 2026-08-11: espanso crashes once per boot and then works.
            # Tabled deliberately -- it recovers on its own and nothing is
            # visibly broken -- but written down so the next person does not
            # start from zero.
            #
            # What was observed on tenacity, generation 66:
            #
            #   15:24:13  SIGSEGV, coredump recorded against
            #             espanso-2.4.0/bin/.espanso-wrapped
            #   15:24:16  restarted by Restart=on-failure, NRestarts=1, and has
            #             stayed active since
            #
            # So it is one crash at session start, not a loop, and the unit is
            # `active` afterwards. Text expansion works.
            #
            # Two warnings it prints on every start, either of which may be
            # related and both worth ruling out first, since they are cheap:
            #
            #   "unable to determine keyboard layout automatically, please
            #    explicitly specify it in the configuration"   (twice)
            #
            # -- fixable here with a `keyboard_layout` block in the config
            # below, and the more likely of the two to matter.
            #
            #   "Can't read from device /dev/input/event15, this error usually
            #    means the device has been disconnected, removing from epoll"
            #
            # -- that one is at 16:23:28, immediately after a resume from
            # suspend, so it is espanso losing an evdev device across s2idle
            # rather than the startup crash. A handheld with a built-in
            # controller re-enumerates input devices on wake.
            #
            # Suspected but NOT established: the same start-before-the-
            # compositor race that vicinae had, fixed there by pointing its unit
            # at plasma-workspace.target instead of graphical-session.target.
            # Espanso is a home-manager service, so the equivalent would be
            # overriding systemd.user.services.espanso.Unit.After -- check the
            # timing against the compositor before assuming, which is the step
            # that was skipped for vicinae the first time.
            #
            # Not worth doing until something actually misbehaves: one crash,
            # self-healing, and the coredumps are bounded by
            # nire/system/storage/coredump-limit.nix.
            services.espanso = {
                enable = true;
                waylandSupport = true;
                configs = {
                    default = {
                        search_shortcut = "off";
                        search_trigger = ".espanso";
                    };
                };
            };
        };
}
