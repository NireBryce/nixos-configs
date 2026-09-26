# Cube-side host support for the Forgejo Actions runner, which runs in a
# VM (forge-runner, instantiated by virtualization-cube.nix; its
# config is hosts/forge-runner-configuration.nix). This module is what
# remains on the HOST: the loop that gives every job a fresh VM and a
# fresh single-use runner registration.
#
# One cycle of forge-runner-cycle, repeated forever:
#   1. a new random 40-hex secret, on tmpfs only;
#   2. `forgejo-cli actions register --ephemeral --scope elly` with it --
#      the server-side registration must run where the forge is (the CLI
#      talks to the local DB). The runner's UUID is derived from the
#      secret's first 16 characters (models/actions/forgejo.go), so every
#      cycle is a new runner;
#   3. the secret staged into the virtiofs share (read-only to the guest);
#   4. the guest recreated from its base image and started
#      (libvirt-vm-forge-runner, `ephemeral`, restarted by this loop);
#   5. wait for the guest to power itself off -- it runs `forgejo-runner
#      one-job` and powers off when that exits -- or kill it at a
#      deadline.
# Forgejo deletes an ephemeral runner as soon as its job completes
# (routers/api/actions/runner/runner.go), so a token stolen by a job is
# dead once that job ends. Registrations that never got a job (a guest
# that failed to boot) are swept by forgejo.nix's
# cron.cleanup_offline_runners.
#
# Kept in the wiki, not restated here: the run loop, labels, recovery --
# wiki/categories/git-forge.md and sibling, wiki/homelab/forgejo.md.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { pkgs, config, ... }: {
            # # description = "cube-side support for the Forgejo Actions runner VM";

            # Runs as root: virsh needs the system libvirtd, which the
            # forgejo user cannot reach (polkit refuses it -- hit
            # 2026-09-25, "authentication unavailable: no polkit agent
            # available"). The register call alone drops to the forgejo
            # user, through a secret file only that user can read.
            #
            # A switch that changes THIS script restarts the loop, and the
            # new loop's first step recreates the guest -- killing any job
            # in flight. A switch that changes only the guest does not: the
            # guest's unit is never restarted by a switch (`autostart =
            # false`), so the change lands on the next cycle.
            systemd.services.forge-runner-cycle = {
                description = "Run the Forgejo runner VM, one fresh VM and registration per job";
                # After the admin bootstrap: `--scope elly` names a user that
                # must already exist (forgejo.nix creates it).
                after    = [ "forgejo.service" "forgejo-admin-bootstrap.service" "libvirtd.service" ];
                wants    = [ "forgejo.service" "forgejo-admin-bootstrap.service" ];
                requires = [ "libvirtd.service" ];
                wantedBy = [ "multi-user.target" ];
                path     = with pkgs; [ coreutils util-linux libvirt systemd config.services.forgejo.package ];

                script = ''
                    set -euo pipefail
                    CONFIG=${config.services.forgejo.customDir}/conf/app.ini
                    SHARE=/var/lib/forgejo-runner-share
                    RUNDIR=/run/forge-runner-cycle
                    # The guest's own ceiling is nix's 4h build timeout; this
                    # is the backstop for a guest that never powers off.
                    MAX_SECONDS=16200

                    install -d -m 0700 "$SHARE"
                    short=0
                    install -d -m 0700 -o ${config.services.forgejo.user} -g ${config.services.forgejo.group} "$RUNDIR"

                    while true; do
                        started=$(date +%s)

                        secret=$(od -An -N20 -tx1 /dev/urandom | tr -d ' \n')
                        ( umask 077
                          printf '%s' "$secret" > "$RUNDIR/secret"
                          printf '%s' "$secret" > "$SHARE/forgejo-runner-secret.new" )
                        unset secret
                        chown ${config.services.forgejo.user}:${config.services.forgejo.group} "$RUNDIR/secret"

                        # Prints the new runner's UUID to the journal -- not
                        # secret (the admin UI shows it).
                        runuser -u ${config.services.forgejo.user} -- \
                            forgejo --config "$CONFIG" forgejo-cli actions register \
                                --name forge-runner \
                                --scope elly \
                                --ephemeral \
                                --secret-file "$RUNDIR/secret"
                        # The CLI prints the UUID with no trailing newline;
                        # without this, journald holds it until the next line.
                        echo
                        rm -f "$RUNDIR/secret"
                        mv -f "$SHARE/forgejo-runner-secret.new" "$SHARE/forgejo-runner-secret"

                        # Fresh guest: dropping the stamp makes the
                        # `ephemeral` activation destroy any running domain,
                        # recreate the overlay, and start it.
                        rm -f /run/libvirt-vm/forge-runner.stamp
                        systemctl restart libvirt-vm-forge-runner.service

                        while [ "$(virsh -c qemu:///system domstate forge-runner 2>/dev/null || true)" = "running" ]; do
                            if [ $(( $(date +%s) - started )) -ge "$MAX_SECONDS" ]; then
                                echo "forge-runner still running after ''${MAX_SECONDS}s; destroying"
                                virsh -c qemu:///system destroy forge-runner || true
                                break
                            fi
                            sleep 5
                        done

                        rm -f "$SHARE/forgejo-runner-secret"
                        elapsed=$(( $(date +%s) - started ))
                        echo "forge-runner cycle ended after ''${elapsed}s"
                        # A guest that dies at boot would otherwise spin a
                        # registration every half-minute. One short cycle is
                        # usually a quick real job (31 s, 2026-09-26), so only
                        # the second short cycle in a row backs off.
                        if [ "$elapsed" -lt 120 ]; then short=$(( short + 1 )); else short=0; fi
                        if [ "$short" -ge 2 ]; then sleep 60; fi
                    done
                '';

                serviceConfig = {
                    Restart    = "always";
                    RestartSec = 30;
                };
            };

            # `ssh forge-runner` on cube -- the only place the guest takes
            # SSH from (its authorized key is cube's). The guest is
            # ephemeral, so its host key regenerates on every reset and a
            # remembered one would refuse every time; host-key checking is
            # off for this one bridge address instead. Intercepting
            # virbr0 already takes root on cube.
            programs.ssh.extraConfig = ''
                Host forge-runner 192.168.122.11
                    HostName 192.168.122.11
                    User root
                    StrictHostKeyChecking no
                    UserKnownHostsFile /dev/null
                    LogLevel ERROR
            '';

            # No persistence entry, same reasoning as forgejo.nix: cube has
            # a plain persistent root (cube-configuration.nix's header), so
            # /var/lib/forgejo-runner-share and the VM's overlay disk under
            # /var/lib/libvirt/images survive reboots on their own. If a
            # /root-wiping host ever imports this, add one first, modeled
            # on tailscale-persist.nix.
        };
}
# ── history ─────────────────────────────────────────────────────────────────
#
# 2026-09-24 to 2026-09-26 — one long-lived runner, registered by an
# idempotent oneshot (forgejo-runner-registration) from the sops secret
# `forgejo-runner-secret`: same secret -> same UUID -> existing row,
# no-op'd by token-hash compare. The guest ran nixpkgs'
# services.forgejo-runner in daemon mode with that UUID pinned as a literal
# (UUID 30343634-3961-3333-6665-303732653263), because runner v13 has no
# `uuid_url` file indirection -- nixpkgs' `secrets.*.uuid_url` templating
# renders a key the runner silently drops, the §49 swallowed-key shape.
# Only the pairing with the secret's first 16 characters had to be exact
# (models/actions/forgejo.go, google/uuid.FromBytes). Every job could read
# that token, and it stayed valid across jobs. Its root halves ran as "+"
# ExecStartPosts after the same polkit trap noted above. The sops key and
# its declaration were removed 2026-09-26, once the per-job cycle had run.
