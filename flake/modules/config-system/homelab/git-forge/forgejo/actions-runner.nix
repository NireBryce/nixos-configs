# Forgejo Actions runner: the CI worker for the forge in forgejo.nix.
# Added 2026-09-24, cube-only, part of the `git-forge` category like the
# forge itself. GitHub-Actions-compatible workflow YAML; a job picks this
# runner by `runs-on:` matching a label below.
#
# An outbound-only worker, unlike every other service in this category:
# no listening port, no firewall entry, no Caddy route. It dials Forgejo's
# loopback API (127.0.0.1:3001) for jobs, and docker-executor jobs then
# speak the docker API to podman -- `containers/podman/podman.nix` provides
# the /run/docker.sock symlink (`dockerSocket.enable`).
#
# Registration is the offline scheme (Forgejo v11+ / runner v9+): a 40-char
# hex shared secret whose FIRST 16 CHARACTERS, read as raw ASCII bytes, ARE
# the runner UUID (models/actions/forgejo.go, RegisterRunner ->
# google/uuid.FromBytes). The deprecated registration token is NOT
# supported by the connections config. The secret lives in sops as
# `forgejo-runner-secret` (declared below); the UUID is derived from it and
# PINNED as a literal, because it is not secret (it shows in the admin UI)
# but must reach the runner's generated config.yaml at build time --
# the runner has no `uuid_url` file indirection, only `token_url`
# (checked in runner v13.2.0's serializedConnectionSettings; nixpkgs'
# `secrets.*.uuid_url` templating renders a key the runner DROPS -- the
# §49 swallowed-key shape, which is why this comment exists).
#
# ONE-TIME HAND STEP, the only one (see wiki/homelab/forgejo.md):
#   1. add `forgejo-runner-secret: <openssl rand -hex 20>` to
#      system/secrets/secrets.yaml via sops
#   2. derive the UUID from that same value and paste it into the pinned
#      `uuid` below (one python line, same wiki page).
# Until both are done the eval-time assertion below fails the build, on
# purpose: an empty UUID is a runtime-only auth failure otherwise.
#
# forgejo-runner-registration below re-runs the server-side register on
# every activation -- idempotent by design (same secret -> same UUID ->
# existing runner row, no-op'd by a token-hash compare), and it is what
# creates the runner row the runner then authenticates against.
#
# Kept in the wiki, not restated here: labels at work, writing workflows,
# the run loop, recovery -- wiki/categories/git-forge.md and sibling,
# wiki/homelab/forgejo.md.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { pkgs, config, ... }: {
            # # description = "Forgejo Actions CI runner for the cube forge";

            # Docker-API socket for docker-executor jobs. `podman.nix`'s
            # dockerCompat is only the CLI alias; this is the
            # /run/docker.sock -> podman.socket symlink (SocketGroup podman,
            # which the runner unit is added to by the nixpkgs module). Set
            # HERE and not in podman.nix because `containers` is imported
            # whole by tenacity, and this consumer is cube-only -- keeps
            # tenacity byte-identical.
            virtualisation.podman.dockerSocket.enable = true;

            services.forgejo-runner.instances.cube = {
                enable = true;

                settings = {
                    runner = {
                        # Labels decide which jobs this runner accepts
                        # (workflow `runs-on:`). The ubuntu-* names exist so
                        # GitHub-style workflows run unmodified; plain node
                        # images are the runner project's own recommendation
                        # -- the runner daemon clones with its own git (the
                        # unit always gets gitMinimal in path), so the job
                        # image needs node but not git. `nix:host` runs the
                        # job directly on the host -- what building THIS
                        # repo's configs wants (host nix store/daemon).
                        labels = [
                            "ubuntu-latest:docker://node:24-bookworm"
                            "ubuntu-24.04:docker://node:24-bookworm"
                            "nix:host"
                        ];
                    };

                    server.connections.default = {
                        # Loopback: forgejo.nix's listener. ROOT_URL's FQDN is
                        # irrelevant here -- the runner talks to the listener,
                        # not through Caddy or Tailscale Serve.
                        url = "http://127.0.0.1:3001/";

                        # Pinned runner UUID -- derived from
                        # `forgejo-runner-secret`'s first 16 characters (see
                        # the file header for the derivation and the wiki for
                        # the command). NOT a secret: it is displayed in the
                        # admin UI; only the pairing must be exact.
                        #
                        # Left empty on first land (2026-09-24): filling it
                        # needs the sops value, and only a key holder can add
                        # that. The assertion below fails the build until it
                        # is filled.
                        uuid = "";

                        # token is NOT set inline -- it comes from sops via
                        # `secrets` below, which nixpkgs renders as a systemd
                        # LoadCredential + `token_url: file:...` indirection,
                        # keeping the value out of the world-readable store.
                    };
                };

                # Paths handed to the unit as systemd credentials. The key
                # names must spell the settings path they feed
                # (`token_url` -> settings.server.connections.default.token_url);
                # deliberately NOT `uuid_url` -- the runner drops that key
                # (file header).
                secrets.server.connections.default.token_url =
                    config.sops.secrets.forgejo-runner-secret.path;

                # Packages for `nix:host` jobs -- the default list restated
                # plus nix, since setting the option replaces, not appends.
                hostPackages = with pkgs; [
                    bash
                    coreutils
                    curl
                    gawk
                    gnused
                    nodejs
                    nix
                    wget
                ];
            };

            # Fail the BUILD, not the runner's first start: an empty pin
            # would otherwise render clean and only surface as an auth
            # failure in the runner's journal.
            assertions = [
                {
                    assertion =
                        config.services.forgejo-runner.instances.cube.settings.server.connections.default.uuid != "";
                    message =
                        "actions-runner: the pinned runner UUID is empty. Add the sops secret "
                        + "`forgejo-runner-secret` and derive the UUID from its first 16 characters "
                        + "-- one-time steps documented in wiki/homelab/forgejo.md.";
                }
            ];

            sops.secrets.forgejo-runner-secret = {
                owner = config.services.forgejo.user;
                group = config.services.forgejo.group;
                mode  = "0400";
            };

            # Creates the runner row server-side from the sops secret.
            # Idempotent on every activation (file header); prints the UUID
            # to stdout, which lands in the journal -- fine, it is not
            # secret. Ordered after forgejo.service (needs the migrated DB,
            # same reasoning as forgejo.nix's admin-bootstrap) and before
            # the runner (whose auth against a not-yet-created row would
            # fail until this has run once).
            systemd.services.forgejo-runner-registration = {
                description = "Register the Forgejo Actions runner against the forge";
                after      = [ "forgejo.service" ];
                wants      = [ "forgejo.service" ];
                before     = [ "forgejo-runner-cube.service" ];
                wantedBy   = [ "multi-user.target" ];
                path       = [ config.services.forgejo.package ];

                script = ''
                    set -euo pipefail
                    CONFIG=${config.services.forgejo.customDir}/conf/app.ini
                    SECRET_FILE=${config.sops.secrets.forgejo-runner-secret.path}

                    forgejo --config "$CONFIG" forgejo-cli actions register \
                        --name cube \
                        --secret-file "$SECRET_FILE"
                '';

                serviceConfig = {
                    Type            = "oneshot";
                    RemainAfterExit = true;
                    User            = config.services.forgejo.user;
                    Group           = config.services.forgejo.group;
                };
            };

            # No persistence entry, same reasoning as forgejo.nix: cube has
            # a plain persistent root (cube-configuration.nix's header), so
            # /var/lib/forgejo-runner/cube (the runner's state dir) survives
            # reboots on its own. If a /root-wiping host ever imports this,
            # add one first, modeled on tailscale-persist.nix.
        };
}
