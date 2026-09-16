# flake-lock-bump: the weekly flake.lock bump, moved off GitHub's runner so
# the update is BUILT on real hardware before a PR is proposed, not only
# evaluated in CI (issue #205 -- the runner could evaluate, and §§36-37 are
# exactly the failure that leaves invisible until someone builds). Own nested
# category under homelab/, same shape as backup: a timer, not a listener.
#
# Replaces .github/workflows/update-flake-lock.yml (deleted with this): same
# Monday 09:00 UTC slot, same update_flake_lock_action branch, same PR text;
# the workflow's token preflight and its failure/expiry issue-filing live in
# flake/scripts/lock-bump.sh now. The property that the PR *makes* CI run
# survives -- the PR is opened with a credential that triggers
# pull_request workflows where GITHUB_TOKEN would not.
#
# THE CREDENTIAL: elly's existing `gh auth` login on cube (hosts.yml), not a
# sops key -- decided 2026-09-16 after the original sops design here: the
# PAT had already been rotated into the (now obsolete) FLAKE_LOCK_TOKEN
# Actions secret, whose write-only value forced a fresh mint plus a
# sops-set-before-next-build ordering constraint, while a working, scoped
# credential was already sitting in elly's gh config on this same box. Using
# it adds no new exposure and deletes the manual step and the
# declared-but-unset-key build failure the sops shape carried. No expiry
# (gh OAuth logins have none), so the weekly preflight's early-warning
# degrades to "cannot tell" -- logged as a notice, not a failure, same gap
# the workflow documented. Full account: wiki/categories/lock-bump.md and
# wiki/maintenance-schedule.md item 10.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { pkgs, ... }:
            let
                # `pkgs` bound on the inner module, not the outer flake-parts
                # scope -- same trap-and-explanation as restic.nix's.
                lockBumpScript = pkgs.writeShellApplication {
                    name = "flake-lock-bump";
                    runtimeInputs = with pkgs; [
                        coreutils
                        curl
                        deadnix      # the lint ratchet's other half
                        gh
                        git
                        nix
                        python3      # modules.py + lint.py
                        statix
                        systemd      # journalctl, for alert mode's excerpt
                    ];
                    text = builtins.readFile ../../../../scripts/lock-bump.sh;
                };
            in {
                # On PATH for interactive debugging, same reasoning as
                # restic.nix keeping plain `restic` in systemPackages.
                environment.systemPackages = [ lockBumpScript ];

                systemd = {
                    services.flake-lock-bump = {
                        description = "Weekly flake.lock bump, built on cube before the PR is proposed";
                        after = [ "network-online.target" ];
                        wants = [ "network-online.target" ];
                        # Runs as `elly` -- the credential is elly's gh login
                        # (hosts.yml), and `elly` is hardcoded by the same
                        # convention as users.users.elly. HOME is set
                        # explicitly because gh reads ~/.config/gh/hosts.yml
                        # and relying on systemd's implicit $HOME for User=
                        # services is not worth a timer.
                        environment = { HOME = "/home/elly"; };
                        serviceConfig = {
                            Type = "oneshot";
                            ExecStart = lib.getExe lockBumpScript;
                            # Minutes most weeks (everything substitutable), but
                            # the week nixpkgs actually moved, this IS the build.
                            TimeoutStartSec = "4h";
                            StateDirectory = "flake-lock-bump";
                            User = "elly";
                        };
                        # Loud failure -- #205's own warning about timers: a red
                        # Actions run at least emailed; a failed unit here would
                        # notify no one without this. Files into the same
                        # reusable issue title the old workflow used.
                        onFailure = [ "flake-lock-bump-alert.service" ];
                    };

                    services.flake-lock-bump-alert = {
                        description = "File an issue about a failed flake-lock-bump run";
                        # Same user, same reason: the alert needs the same gh
                        # login to file anything at all.
                        environment = { HOME = "/home/elly"; };
                        serviceConfig = {
                            Type = "oneshot";
                            ExecStart = "${lib.getExe lockBumpScript} alert";
                            User = "elly";
                        };
                    };

                    timers.flake-lock-bump = {
                        wantedBy = [ "timers.target" ];
                        timerConfig = {
                            # The cron slot the deleted workflow ran on.
                            OnCalendar         = "Mon *-*-* 09:00:00 UTC";
                            # Cube being down at slot time is the expected case
                            # some weeks; Persistent means the run happens at
                            # next boot instead of being skipped.
                            Persistent         = true;
                            RandomizedDelaySec = "15m";
                        };
                    };
                };
            };
}
