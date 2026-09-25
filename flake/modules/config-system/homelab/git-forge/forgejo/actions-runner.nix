# Cube-side host support for the Forgejo Actions runner, which runs in a
# VM (forge-runner, instantiated by virtualization-cube.nix; its
# config is hosts/forge-runner-configuration.nix). This module is what
# remains on the HOST, and everything here exists for one of three
# reasons:
#
#   - the sops secret decrypts on cube (host-key recipient; the VM has no
#     key and deliberately runs no sops),
#   - the server-side registration must run where the forge is (the CLI
#     talks to the local DB), and
#   - the guest gets its token by virtiofs from a staged copy of the
#     decrypted secret, so cube stages that copy.
#
# The runner process itself -- services.forgejo-runner, its labels, its
# pinned UUID -- lives in the guest configuration, not here. Same split
# as when this was the host runner (2026-09-24): the token rides
# `secrets.*.token_url` as a systemd LoadCredential, never inline,
# because runner v13 has no `uuid_url` file indirection -- nixpkgs'
# `secrets.*.uuid_url` templating renders a key the runner silently
# drops, the §49 swallowed-key shape, which is why the UUID is a pinned
# literal in the guest config. It is not secret (the admin UI shows it);
# only the pairing with the secret's first 16 characters must be exact
# (models/actions/forgejo.go, google/uuid.FromBytes -- the deprecated
# registration token is not supported).
#
# The registration oneshot is idempotent by design (same secret -> same
# UUID -> existing row, no-op'd by token-hash compare) and is what
# creates the row the runner authenticates against. Ordering sees the
# guest not start before registration ran: libvirt-vm-forge-runner is
# After= this unit.
#
# Kept in the wiki, not restated here: the run loop, labels, recovery --
# wiki/categories/git-forge.md and sibling, wiki/homelab/forgejo.md.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { pkgs, config, ... }: {
            # # description = "cube-side support for the Forgejo Actions runner VM";

            sops.secrets.forgejo-runner-secret = {
                owner = config.services.forgejo.user;
                group = config.services.forgejo.group;
                mode  = "0400";
            };

            # Idempotent on every activation; prints the UUID to stdout,
            # which lands in the journal -- fine, it is not secret. Ordered
            # after forgejo.service (needs the migrated DB, same reasoning
            # as forgejo.nix's admin-bootstrap).
            #
            # TRAP, hit on the first real switch 2026-09-25: the main
            # script runs as the forgejo user, and the forgejo user cannot
            # talk to the system libvirtd -- virsh dies with
            # "authentication unavailable: no polkit agent available"
            # (org.libvirt.unix.manage), which took the whole unit down
            # and, cascading, left the VM without its staged token copy.
            # So the privileged halves live in root-privileged
            # ExecStartPosts ("+" prefix, listed in execution order, run
            # only after the register succeeded); the forgejo-user script
            # does only what needs the forge user.
            systemd.services.forgejo-runner-registration = {
                description = "Register the Forgejo Actions runner against the forge";
                after      = [ "forgejo.service" ];
                wants      = [ "forgejo.service" ];
                wantedBy   = [ "multi-user.target" ];
                path       = with pkgs; [ config.services.forgejo.package coreutils ];

                script = ''
                    set -euo pipefail
                    CONFIG=${config.services.forgejo.customDir}/conf/app.ini
                    SECRET_FILE=${config.sops.secrets.forgejo-runner-secret.path}

                    forgejo --config "$CONFIG" forgejo-cli actions register \
                        --name forge-runner \
                        --secret-file "$SECRET_FILE"
                '';

                serviceConfig = {
                    Type            = "oneshot";
                    RemainAfterExit = true;
                    User            = config.services.forgejo.user;
                    Group           = config.services.forgejo.group;
                    ExecStartPost   = [
                        # Stage the guest's token copy (the "+" prefix runs
                        # an ExecStartPost as root, outside User=/Group=):
                        # the share dir holds ONLY this file, root:root 0600,
                        # which is what virtiofs passthrough shows the guest
                        # -- guest root (systemd, reading LoadCredential)
                        # can read it; no one else on either side needs to.
                        "+${pkgs.runtimeShell} -c 'install -d -m 0700 /var/lib/forgejo-runner-share && install -m 0600 ${config.sops.secrets.forgejo-runner-secret.path} /var/lib/forgejo-runner-share/forgejo-runner-secret'"
                    ];
                };
            };

            # The guest must not boot before its token copy is staged and
            # registration has run; its runner unit additionally
            # self-heals (Restart=on-failure) if the window is ever lost.
            systemd.services."libvirt-vm-forge-runner".after =
                [ "forgejo-runner-registration.service" ];

            # No persistence entry, same reasoning as forgejo.nix: cube has
            # a plain persistent root (cube-configuration.nix's header), so
            # /var/lib/forgejo-runner-share and the VM's overlay disk under
            # /var/lib/libvirt/images survive reboots on their own. If a
            # /root-wiping host ever imports this, add one first, modeled
            # on tailscale-persist.nix.
        };
}
