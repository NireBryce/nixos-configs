# flake-lock-bump: the weekly flake.lock bump, moved off GitHub's runner so
# the update is BUILT on real hardware before a PR is proposed, not only
# evaluated in CI (issue #205 -- the runner could evaluate, and §§36-37 are
# exactly the failure that leaves invisible until someone builds). Own nested
# category under homelab/, same shape as backup: a timer, not a listener,
# with one sops secret consumed via config.sops.secrets.<name>.path.
#
# Replaces .github/workflows/update-flake-lock.yml (deleted with this): same
# Monday 09:00 UTC slot, same update_flake_lock_action branch, same PR text;
# the workflow's token preflight and its failure/expiry issue-filing live in
# flake/scripts/lock-bump.sh now. The property that PR *makes* CI run
# survives -- the PR is opened with the same kind of PAT, and a PAT-opened PR
# triggers this repo's pull_request workflows where a GITHUB_TOKEN one would
# not (that whole trade is documented in the deleted workflow's header and
# wiki/maintenance-schedule.md item 10).
#
# THE TOKEN, and the ordering constraint that goes with it: `flake-lock-token`
# in secrets.yaml. Its value had to be minted by hand either way -- the old
# Actions secret was write-only, unreadable even by Elly -- and a secret
# declared HERE with no value in secrets.yaml fails at BUILD time, not
# runtime (how restic-cube-password first bit; see restic.nix's header). So
# the sops set must happen BEFORE the next cube build/switch after this
# lands. Full account: wiki/categories/lock-bump.md and
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
                sops.secrets.flake-lock-token = { };

                # On PATH for interactive debugging, same reasoning as
                # restic.nix keeping plain `restic` in systemPackages.
                environment.systemPackages = [ lockBumpScript ];

                systemd = {
                    services.flake-lock-bump = {
                        description = "Weekly flake.lock bump, built on cube before the PR is proposed";
                        after = [ "network-online.target" ];
                        wants = [ "network-online.target" ];
                        serviceConfig = {
                            Type = "oneshot";
                            ExecStart = lib.getExe lockBumpScript;
                            # Minutes most weeks (everything substitutable), but
                            # the week nixpkgs actually moved, this IS the build.
                            TimeoutStartSec = "4h";
                            StateDirectory = "flake-lock-bump";
                        };
                        # Loud failure -- #205's own warning about timers: a red
                        # Actions run at least emailed; a failed unit here would
                        # notify no one without this. Files into the same
                        # reusable issue title the old workflow used.
                        onFailure = [ "flake-lock-bump-alert.service" ];
                    };

                    services.flake-lock-bump-alert = {
                        description = "File an issue about a failed flake-lock-bump run";
                        serviceConfig = {
                            Type = "oneshot";
                            ExecStart = "${lib.getExe lockBumpScript} alert";
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
