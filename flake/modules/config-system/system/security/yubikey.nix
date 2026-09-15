{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { config, pkgs, ... }:
        let
            # The udev add rule below runs this: foregrounding the session wakes
            # the display, so inserting the YubiKey lights up the lock screen the
            # remove rule just locked. `loginctl activate 1` -- what this rule did
            # before -- activated *session 1*, and session ids increment across
            # relogins, so it kept drifting off the graphical session (it was 4,
            # not 1, on tenacity 2026-09-14). Only seated sessions qualify:
            # several of a user's sessions can report State=active at once (on
            # tenacity, an unseated class=manager session tied with the
            # graphical one), and the unseated ones cannot be foregrounded.
            # Absolute paths throughout: udev's RUN+ environment has no usable
            # PATH.
            wakeSession = pkgs.writeShellScript "yubikey-wake-session" ''
                target=
                fallback=
                for sid in $(${pkgs.systemd}/bin/loginctl list-sessions --no-legend | \
                              ${pkgs.gawk}/bin/awk -v user="$1" '$3 == user { print $1 }'); do
                    seat=$(${pkgs.systemd}/bin/loginctl show-session "$sid" -p Seat --value)
                    [ -n "$seat" ] || continue
                    if [ "$(${pkgs.systemd}/bin/loginctl show-session "$sid" -p State --value)" = active ]; then
                        target=$sid
                        break
                    fi
                    [ -n "$fallback" ] || fallback=$sid
                done
                session=''${target:-$fallback}
                [ -n "$session" ] && exec ${pkgs.systemd}/bin/loginctl activate "$session"
            '';
        in {
            # # description = "YubiKey: u2f PAM, udev lock/wake rules, pcscd, OATH app, ykman";
            environment.systemPackages = with pkgs; [
                pam_u2f
                yubioath-flutter
                yubikey-manager
            ];

            # This is linux only, and the reference for the required services
            # and config below: see Dr. Duh NixOS config
            services = {
                udev = {
                    extraRules = ''
                        # Any YubiKey model. HID_NAME varies by model and by which USB
                        # interfaces are enabled (FIDO+CCID, OTP+FIDO+CCID, FIDO, ...),
                        # and the remove event carries no ID_VENDOR_ID to match on
                        # instead, so match the shared prefix.
                        SUBSYSTEM=="hid",\
                        ACTION=="remove",\
                        ENV{HID_NAME}=="Yubico YubiKey*",\
                        RUN+="${pkgs.systemd}/bin/loginctl lock-sessions"

                        SUBSYSTEM=="hid",\
                        ACTION=="add",\
                        ENV{HID_NAME}=="Yubico YubiKey*",\
                        RUN+="${wakeSession} ${config.users.users.elly.name}"
                    '';
                    packages = [ pkgs.yubikey-personalization ];
                };
                pcscd.enable = true; # smartcard service
            };

            # Login with a YubiKey touch instead of a password. One enable turns
            # u2f on for EVERY PAM service -- each service's u2fAuth defaults to
            # security.pam.u2f.enable (nixpkgs pam.nix) -- so login, sudo, the
            # KDE lock screen, polkit and sshd all get the `sufficient` rule,
            # and hosts without the key plugged in fall through to the
            # password. Deliberately not restated per service: the default is
            # the mechanism, and a per-service list would drift from it.
            #
            # `authfile` is lowercase. Nixpkgs renamed
            # security.pam.u2f.authFile -> settings.authfile; settings is
            # freeform, so the camelCase spelling passed eval and reached
            # pam_u2f as an unknown module argument, which it discards
            # silently. Masked 2026-04..2026-09-14 because the explicit path
            # equaled pam_u2f's built-in default
            # ($XDG_CONFIG_HOME/Yubico/u2f_keys).
            security.pam.u2f = {
                enable = true;
                settings = {
                    cue = true; # Tells user they need to press the button
                    authfile = "${config.users.users.elly.home}/.config/Yubico/u2f_keys";
                };
            };
        };
}

# ── history ─────────────────────────────────────────────────────────────────
#
# 2026-09-14 — three silent-failure modes closed, recorded because each one
# looked like it was working:
#
# - `settings.authFile` (camelCase) had been ignored by pam_u2f since the
#   module was written (by 2026-04): the rendered PAM line carried
#   `authFile=`, which pam_u2f discards as an unknown module argument. The
#   explicit `services.login/sudo.u2fAuth = true` beside it were restating a
#   default (u2fAuth defaults to u2f.enable per service) and went with the
#   rewrite.
# - Both udev rules matched HID_NAME exactly `Yubico YubiKey FIDO+CCID` (the
#   then-only key, USB 1050:0406). A second model, or re-enabling the OTP
#   interface on this one, would have silently stopped lock-on-remove.
# - The add rule ran `loginctl activate 1` — session 1, not VT 1 — replaced by
#   the wakeSession script. `xset` had been tried for the wake and doesn't
#   work from udev; that was the old INEEDFIX.
