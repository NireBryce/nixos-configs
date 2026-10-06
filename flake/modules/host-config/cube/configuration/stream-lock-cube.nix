# Puts Plasma's lock screen in front of cube's autologin session
# (headless-display-cube.nix), so both the console and a Moonlight client
# need elly's password; added 2026-10-06. Three points lock it:
#
# - Login: an XDG autostart entry locks as soon as Plasma starts.
# - App quit: Sunshine's `global_prep_cmd` runs `undo` when the streamed app
#   ends. Only then -- a client disconnecting without quitting leaves the
#   app running and runs nothing (Sunshine src/process.cpp, proc_t::terminate).
# - Disconnect without quit: Plasma's idle auto-lock, default 5 minutes. cube
#   has no kscreenlockerrc, so the default applies.
#
# Locks through org.freedesktop.ScreenSaver on the session bus, not
# `loginctl lock-session`: neither the autostart entry nor Sunshine's user
# service runs inside a logind session, so logind has no session to lock and
# polkit treats the caller as inactive. Retries because the autostart entry
# can run before kscreenlocker has claimed the bus name.
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
                # # description = "cube: lock Plasma at login and when a Sunshine app quits";
                environment.etc."xdg/autostart/cube-lock-on-login.desktop".text = ''
                    [Desktop Entry]
                    Type=Application
                    Name=Lock session after autologin
                    Exec=${lib.getExe lockSession}
                    NoDisplay=true
                '';

                services.sunshine.settings.global_prep_cmd = builtins.toJSON [
                    { do = ""; undo = lib.getExe lockSession; }
                ];
            };
}
