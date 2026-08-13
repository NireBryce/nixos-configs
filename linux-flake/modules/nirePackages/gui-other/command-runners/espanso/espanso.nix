{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        # An argument list was added here on 2026-08-12, where there was
        # previously a bare attrset. That is normally the trap CLAUDE.md warns
        # about -- adding `{ ... }:` repoints every `config` in the body from
        # the flake-parts scope to the Home Manager one -- but this body never
        # referenced `config`, only `services.espanso`, so nothing moved.
        flake.modules.homeManager.${moduleName} = { pkgs, lib, ... }:
            # Excluded on darwin, and NOT for the reason kitty.nix is. kitty
            # keeps its config there and only drops the binary; espanso cannot,
            # for three separate reasons, any one of which would be enough:
            #
            #   1. services.espanso.package is `mkPackageOption pkgs "espanso"
            #      { }` -- not nullable. (package-wayland is the nullable one.)
            #      So there is no `package = null` to reach for.
            #
            #   2. The module writes xdg.configFile."espanso/config/*.yml", ie
            #      ~/.config/espanso. macOS espanso does not read that. Checked
            #      on lysithea against the installed cask:
            #
            #          $ espanso path
            #          Config: /Users/elly/Library/Application Support/espanso
            #
            #      ~/.config/espanso does not exist on that machine. The
            #      settings below would land somewhere nothing reads.
            #
            #   3. Worst of the three: the module also declares
            #      launchd.agents.espanso, pointing at the nix store's
            #      Espanso.app. The homebrew cask's agent is already loaded and
            #      running there -- `launchctl list` shows
            #      com.federicoterzi.espanso -- so this would start a SECOND
            #      text expander racing the first for the same keystrokes.
            #
            # If the settings below are wanted on lysithea, the honest way is a
            # home.file entry under "Library/Application Support/espanso", not
            # this module. Note that path already holds espanso's own stock
            # default.yml, so Home Manager would refuse to clobber it and fail
            # activation until that file is moved out of the way.
            lib.mkIf (!pkgs.stdenv.isDarwin) {
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
