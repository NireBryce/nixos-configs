# Puts Plasma's lock screen in front of cube's autologin session
# (headless-display-cube.nix), so both the console and a Moonlight client
# need elly's password, and requires encryption on Sunshine streams; added
# 2026-10-06. Three points lock it:
#
# - Login: kscreenlocker's `LockOnStart` locks as soon as the locker starts
#   (ksldapp.cpp, KSldApp::initialize -> lock(EstablishLock::Immediate)).
# - App quit: Sunshine's `global_prep_cmd` runs `undo` when the streamed app
#   ends. Only then -- a client disconnecting without quitting leaves the
#   app running and runs nothing (Sunshine src/process.cpp, proc_t::terminate).
# - Disconnect without quit: idle auto-lock, cut from the 5-minute default to
#   2. `LockGrace` goes from 5 seconds to 0: during the grace period after an
#   idle lock, any input unlocks without a password (ksldapp.cpp, the
#   KIdleTime::timeoutReached handler sets m_inGraceTime).
#
# kscreenlockerrc's [Daemon] group is marked `[$i]` (KConfig immutable), so a
# ~/.config/kscreenlockerrc can't override it; the Screen Locking page in
# System Settings can't change these on cube. Keys and defaults are from
# kscreenlocker's settings/kscreenlockersettings.kcfg (6.7.5).
#
# The Sunshine undo step locks through org.freedesktop.ScreenSaver on the
# session bus, not `loginctl lock-session`: Sunshine's user service runs
# outside any logind session, so logind has no session to lock and polkit
# treats the caller as inactive. Retries in case the locker hasn't claimed
# the bus name yet.
#
# `lan_encryption_mode = 2` rejects unencrypted streams. Sunshine classifies
# 100.64.0.0/10 as LAN (src/network.cpp, lan_ips), so tailnet clients fall
# under the LAN setting, whose default is 0 (no encryption).
#
# Setting any `services.sunshine.settings` key makes the module pass a store
# config file, which makes Sunshine's web-UI settings read-only. cube's
# ~/.config/sunshine/sunshine.conf was empty when this was added. apps.json,
# pairing and web-UI credentials still live in ~/.config/sunshine, which
# Sunshine resolves from its appdata dir, not the config file's (src/config.cpp,
# path_f).
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { pkgs, ... }:
            let
                lockSession = pkgs.writeShellApplication {
                    name          = "cube-lock-session";
                    runtimeInputs = with pkgs; [
                        coreutils
                        dbus
                    ];
                    text = ''
                        for _ in $(seq 30); do
                            if dbus-send --session --print-reply --dest=org.freedesktop.ScreenSaver \
                                /ScreenSaver org.freedesktop.ScreenSaver.Lock >/dev/null 2>&1; then
                                exit 0
                            fi
                            sleep 1
                        done
                        echo "cube-lock-session: org.freedesktop.ScreenSaver.Lock failed for 30s" >&2
                        exit 1
                    '';
                };
            in {
                # # description = "cube: lock Plasma at login, on idle and when a Sunshine app quits; encrypted streams only";
                environment.etc."xdg/kscreenlockerrc".text = ''
                    [Daemon][$i]
                    Autolock=true
                    Timeout=2
                    Lock=true
                    LockGrace=0
                    RequirePassword=true
                    LockOnResume=true
                    LockOnStart=true
                '';

                services.sunshine.settings = {
                    global_prep_cmd     = builtins.toJSON [
                        { do = ""; undo = lib.getExe lockSession; }
                    ];
                    lan_encryption_mode = 2;
                };
            };
}
