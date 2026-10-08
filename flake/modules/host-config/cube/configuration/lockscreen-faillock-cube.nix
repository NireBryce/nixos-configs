# Failed-attempt lockout on cube's Plasma lock screen (stream-lock-cube.nix):
# 5 wrong passwords within 15 minutes refuse password unlock for 10 minutes;
# added 2026-10-07. Only the `kde` PAM service (kscreenlocker's, set in
# kscreenlocker's greeter/CMakeLists.txt) gets it -- sddm, sudo, login and
# sshd are untouched, so `ssh ts-cube sudo faillock --user elly --reset`
# clears a lockout early.
#
# cube has no monitor, so its lock screen is in practice only reachable
# through Sunshine. PAM sees keystrokes, not which device sent them, so this
# applies to every attempt at the lock screen. Password is the only working
# factor there: the u2f rule (order 10900) is in the stack, but u2f login is
# registered for tenacity only. During a lockout the way in is waiting out
# unlock_time or the ssh reset above.
#
# Stack, by order (nixpkgs' own rules: u2f 10900, unix 13100 `sufficient`,
# deny 13900):
# - 10950 preauth, `requisite`: refuses at once while locked out.
# - 13800 authfail, `[default=die]`: reached only when pam_unix didn't
#   succeed; records the failure.
# No authsucc/account rule: kscreenlocker calls pam_authenticate only, never
# pam_acct_mgmt (greeter/pamauthenticator.cpp), and pam_unix is `sufficient`,
# so nothing after it runs on success. A correct password therefore doesn't
# clear earlier failures; they age out after fail_interval.
#
# The tally file is pre-created owned by elly. kscreenlocker's greeter runs
# PAM as elly, and pam_faillock returns PAM_SUCCESS without recording when it
# can't open or create the tally (EACCES/ENOENT, pam_faillock.c check_tally
# and write_tally) -- with the root-owned default dir and no file, the
# lockout would silently never trigger. /run is tmpfs, so a reboot clears it.
#
# `security.pam.services.<name>.rules` is marked experimental in nixpkgs'
# pam.nix ("subject to breaking changes without notice").
{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    flake.modules.nixos.${moduleName} = { pkgs, ... }:
        let
            faillock         = "${pkgs.pam}/lib/security/pam_faillock.so";
            faillockSettings = {
                deny          = 5;
                fail_interval = 900;
                unlock_time   = 600;
            };
        in {
            # # description = "cube: lock-screen password lockout after 5 failures (pam_faillock on the kde service)";
            security.pam.services.kde.rules.auth = {
                faillock-preauth = {
                    order      = 10950;
                    control    = "requisite";
                    modulePath = faillock;
                    args       = [ "preauth" ];
                    settings   = faillockSettings;
                };
                faillock-authfail = {
                    order      = 13800;
                    control    = "[default=die]";
                    modulePath = faillock;
                    args       = [ "authfail" ];
                    settings   = faillockSettings;
                };
            };

            systemd.tmpfiles.rules = [
                "d /run/faillock      0755 root root -"
                "f /run/faillock/elly 0600 elly root -"
            ];
        };
}
