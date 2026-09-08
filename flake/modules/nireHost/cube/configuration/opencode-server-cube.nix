# opencode serve, as a detachable backend for elly's opencode TUI sessions --
# cube-only, filed next to cube's other host-specific config.
#
# WHY THIS EXISTS: a plain `opencode` TUI exit kills in-flight work. With the
# server running under systemd, the TUI is just a client (`opencode attach`)
# -- exiting it (ctrl+c) detaches, sessions keep going server-side, and are
# resumed with `opencode attach -c` / `-s <id>`. This is opencode's
# serve+attach workflow, made to survive reboots.
#
# FILE PLACEMENT: lives in nireHost/cube/configuration/, where the `cube`
# category's collector picks it up from its subdirectory -- there is no
# import line anywhere; adding the file IS the wiring. `-cube` suffix per
# this directory's convention (nixpkgs-hostPlatform-cube, ...): a module's
# name is its filename, and same-name modules in the same class merge
# silently rather than erroring.
#
# DELIBERATELY NOT a `nire/homelab/` category service: it is one personal
# dev tool for one user, not part of the self-hosted stack (no Caddy route,
# no wiki/categories/ page, nothing here for the other hosts). The homelab
# umbrella exists to make shared services optional per host; this is
# host-private instead.
#
# TAILNET-ONLY BY BIND ADDRESS, not by firewall or proxy: ExecStart resolves
# the tailscale IP at start (`tailscale ip -4`) and `serve --hostname` binds
# ONLY that address -- nothing listens on a LAN or public interface, so
# "only reachable via tailscale" is a property of the socket itself. Reach
# it with `just opencode-attach` (`opencode attach http://ts-cube:3003`;
# `ts-cube` is this host's tailnet device name -- tailscale.nix's trap #1,
# not networking.hostName).
# Why not the repo's usual loopback-behind-a-proxy shape:
#
#   - `opencode attach` is an HTTP/WebSocket client speaking at the root of
#     its URL; it takes bare host:port, so a Caddy path prefix would need
#     stripping that its client never asks for.
#   - Per-node `tailscale serve` (the classic non-svc: kind) would expose a
#     loopback bind cleanly, BUT tailscale-serve.service -- the nixpkgs
#     module behind reverse-proxy/tailscale-services/serve.nix -- re-runs
#     `tailscale serve set-config --all` at every boot, replacing the
#     per-node serve config; a CLI-set entry would not survive, and a user
#     unit cannot order itself After a system unit to reapply it.
#   - Binding the 100.x address needs no firewall change: traffic arriving
#     over tailscale0 is already trusted (networking.nix's
#     trustedInterfaces), and no other interface has anything listening.
#
# PORT 3003: next free 300x on this host -- 3000 grafana, 3001 forgejo,
# 3002 glance (caddy.nix proxies to all three).
#
# STATE: opencode keeps everything under ~/.local/share/opencode (sessions,
# auth). Cube has a plain persistent root (cube-configuration.nix header),
# so no *-persist.nix -- same reasoning golink.nix documents. If a host
# that wipes /root ever imports this, a persistence entry is the first
# thing to add, modeled on tailscale-persist.nix.
#
# NOT HARDENED on purpose: the point of the server is that sessions read
# and edit files across elly's home and run shells/build tools;
# ProtectHome or RestrictAddressFamilies-style sandboxing would break the
# tool it exists to serve. Same call sunshine.nix made.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { pkgs, lib, ... }: {
            # # description = "opencode serve: detachable TUI sessions for elly, bound tailnet-only";

            # A systemd --user manager only runs while its user is logged in
            # WITHOUT linger, so the unit would never auto-start at boot.
            # This is the declarative form of `loginctl enable-linger elly`.
            users.users.elly.linger = true;

            # A user (not system) unit: the state is elly's
            # (~/.local/share), and `systemctl --user` needs no sudo, which
            # on cube wants a password. The NixOS side writes the unit
            # file; HM's systemd module is not involved.
            systemd.user.services.opencode-server = {
                description = "opencode serve -- detachable opencode sessions, tailnet-only";
                wantedBy    = [ "default.target" ];

                serviceConfig = {
                    Type = "simple";

                    # The sh -c is load-bearing: ExecStart does no command
                    # substitution, and the bind address has to be resolved
                    # at start -- hardcoding the 100.x address here would
                    # break silently the day the tailnet reissues it.
                    # `exec` keeps the shell from wrapping the server
                    # process. The tailscaled control socket is
                    # world-connectable, so this works from the user
                    # manager (verified: `tailscale ip -4` as elly on cube).
                    ExecStart = "${pkgs.runtimeShell} -c 'exec ${lib.getExe pkgs.opencode} serve --hostname $(${lib.getExe pkgs.tailscale} ip -4) --port 3003'";

                    # No After=/Wants= on tailscaled: the user manager
                    # cannot order against system units at all. If the
                    # `tailscale ip -4` above runs before tailscaled is
                    # answering, ExecStart fails -- Restart=on-failure
                    # retries every 5s until it isn't.
                    Restart    = "on-failure";
                    RestartSec = "5s";

                    # systemd --user's default PATH is thin; serve-mode
                    # sessions spawn shells, git, and build tools, which
                    # need the system and HM profiles. ExecStart itself is
                    # absolute store paths either way.
                    Environment = "PATH=/run/wrappers/bin:/etc/profiles/per-user/elly/bin:/run/current-system/sw/bin";
                };

                # NixOS systemd.user.services is GLOBAL: the unit lands in
                # /etc/systemd/user, which every user manager reads, and
                # wantedBy enables it in all of them. Without this
                # condition, sddm's manager (user@175, alive whenever the
                # greeter session is) starts its own copy; if it wins the
                # race to port 3003, elly's copy crash-loops on ServeError
                # forever and attach talks to a server running as sddm --
                # wrong cwd (/var/lib/sddm as the default project), wrong
                # state dir. Hit 2026-09-08 on cube. ConditionUser makes
                # the unit a no-op in every other user's manager.
                unitConfig.ConditionUser = "elly";
            };
        };
}
