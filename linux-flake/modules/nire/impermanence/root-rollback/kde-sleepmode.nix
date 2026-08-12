# The desktop half of `nohibernate`. Filed beside WARN-impermanence.nix because
# that is what creates the requirement, not because it is about KDE.
#
# WARN-impermanence.nix sets `nohibernate` and turns off AllowHibernation,
# AllowHybridSleep and AllowSuspendThenHibernate -- a host that wipes /root on
# boot cannot survive resuming an image that predates the wipe. PowerDevil
# shipped here asking for hybrid sleep. logind answers CanHybridSleep=no, and
# PowerDevil drops a refused request rather than degrading to plain suspend, so
# suspend stopped working entirely on 2026-08-10. See lessons.md §30.
#
# This is not a preference. It is the other half of a system-level decision, and
# the two have to agree or the machine cannot sleep.
#
# It applies to **both hosts**, which is why it is here rather than under
# desktop-env or with the handheld modules: durandal imports the `boot` category
# too, so it also has `nohibernate`, and its PowerDevil would fail identically.
# Anything that gives one host `nohibernate` gives it this.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, lib, ... }:
            # KDE-specific, and `impermanence` is imported by every host
            # (elly-home-manager.nix) since nohibernate applies to every host
            # too. Guarded here rather than at the import, which cannot depend
            # on pkgs.stdenv.isLinux without an infinite recursion under
            # useGlobalPkgs -- see elly-home-manager.nix's own comment on
            # exactly this.
            lib.mkIf (!pkgs.stdenv.isDarwin) {
            # # description = "KDE sleep mode, kept in step with nohibernate";

            # kwriteconfig6 rather than home.file, deliberately.
            #
            # powerdevilrc is written by KDE itself -- System Settings edits it,
            # and it holds far more than this one key. Declaring the file would
            # make it a read-only store symlink, so the GUI could no longer save
            # anything in it, and this config would have to own every setting in
            # the file to avoid dropping the rest. The same trade was rejected
            # for ~/.vscode/argv.json, for the same reason.
            #
            # This writes one key and leaves the file mutable and otherwise
            # alone.
            #
            # Absolute store path because home-manager activation runs as a
            # systemd unit whose PATH is only coreutils/findutils/gnugrep/
            # gnused/systemd -- see CLAUDE.md. Absolute --file for the same
            # reason: XDG_CONFIG_HOME is not reliably set there.
            #
            # SleepMode = 1 is SuspendToRam. PowerDevil's enum, from
            # plasma/powerdevil daemon/powerdevilenums.h:
            #     SuspendToRam = 1, HybridSuspend = 2, SuspendThenHibernate = 3
            # 2 and 3 both want hibernation and will silently do nothing here.
            #
            # The three profile groups are the ones powerdevilrc uses; nested
            # groups are repeated --group arguments. Verify with:
            #     kreadconfig6 --file powerdevilrc \
            #         --group AC --group SuspendAndShutdown --key SleepMode
            home.activation.kdeSleepMode =
                lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                    for profile in AC Battery LowBattery; do
                        run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
                            --file "$HOME/.config/powerdevilrc" \
                            --group "$profile" --group SuspendAndShutdown \
                            --key SleepMode 1
                    done
                '';
        };
}
