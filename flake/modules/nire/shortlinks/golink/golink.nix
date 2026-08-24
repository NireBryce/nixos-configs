# golink: tailscale's `go/foo` shortlink service, run as its OWN node on the
# tailnet. Added 2026-08-24, cube-only, own category (`nire/shortlinks/`) for
# the same "if something shared needs to be optional, a category is the
# mechanism" reason `monitoring`, `virtualization` and `git-forge` already
# give (CLAUDE.md's Architecture section) -- nothing here belongs on the
# handhelds, and durandal has not asked for it.
#
# The category is named `shortlinks`, not `golink`: a category and its one
# module both named `golink` would declare the same
# `flake.modules.nixos.golink` attribute and silently MERGE rather than
# error -- the `containers`/`podman.nix` collision CLAUDE.md documents, hit
# for real writing `git-forge` a few hours before this file. `shortlinks`
# is deliberately not `golinks` either; one letter apart from the module
# name is the kind of near-collision that reads as a typo later.
#
# THERE IS NO `services.golink` IN NIXPKGS. Checked the pinned nixpkgs
# (rev e4bae1bd, 2026-01-16) before hand-writing this unit, per this repo's
# own "check for an existing programs.*/services.* integration before
# hand-writing one" rule: `pkgs/by-name/go/golink/` exists, and
# `nixos/modules/` has nothing golink-shaped at all. So this is one of the
# rare modules here that writes its own systemd unit rather than setting
# options on an upstream one -- unlike forgejo.nix/grafana.nix next door.
# If nixpkgs ever grows `services.golink`, delete this unit and use it.
#
# THIS IS NOT A SERVICE ON THIS HOST'S NETWORK. golink embeds tsnet, so it
# joins the tailnet as a SEPARATE DEVICE with its own tailnet IP, and its
# `:80`/`:443` listeners live on that device -- not on any of nire-cube's
# own interfaces. Three things follow, all of which distinguish this from
# grafana.nix and forgejo.nix:
#
#   - No firewall change of any kind. Not an allowedTCPPorts entry, and not
#     the `trustedInterfaces = [ "tailscale0" ]` mechanism those two rely
#     on either -- nothing ever arrives at nire-cube's own firewall for
#     this. It is not reachable on the LAN because it does not listen there.
#   - No dependency on the host's `tailscaled` (system/networking/
#     tailscale.nix). tsnet is a full userspace WireGuard node in-process,
#     talking to the coordination server itself; it does not use the host's
#     tunnel, its `tailscale0` interface, or /dev/net/tun. `after` below is
#     just `network-online.target`, deliberately not `tailscaled.service`.
#   - It consumes a tailnet device slot, and the tailnet ACL applies to it
#     like any other member. Per tailscale.nix's "TWO REAL TRAPS": an ACL
#     that doesn't grant member-to-member traffic silently drops
#     connections here too, with nothing in this repo to fix.
#
# FIRST RUN NEEDS A ONE-TIME LOGIN, BY DESIGN. tsnet wants a `TS_AUTHKEY`,
# and this module deliberately does not supply one -- same call, for the
# same reason, tailscale.nix makes for not wiring `authKeyFile`: tailscale
# auth keys expire (90 days maximum), so baking one in mostly buys a unit
# that fails on every boot months from now. Without a key, tsnet prints an
# auth URL and waits. Confirmed by reading tsnet v1.96.1's own source
# (`printAuthURLLoop`, tsnet/tsnet.go) rather than assuming: that message
# goes through `(*Server).logf`, which falls through to `log.Printf` when
# `UserLogf` is nil -- and golink sets only `Logf`, never `UserLogf`. So
# the URL lands on stderr, i.e. in the journal, WITHOUT needing `-verbose`.
# To bring it up the first time:
#
#     journalctl -u golink -f      # then open the printed URL, once
#
# tsnet writes its node key into the config-dir below and reauthenticates
# itself from that on every later boot, so this is once per machine, not
# once per boot -- exactly the shape `sudo tailscale up` already has on
# these hosts. (tsnet.go also logs "Authkey is set; but state is X.
# Ignoring authkey" when state already exists, so an expired key wired in
# later would not break an already-authenticated node -- but there's still
# no reason to wire one.) To revisit anyway: mint a key, add
# `sops.secrets.tailscale_key` in system/secrets/sops.nix (nothing declares
# it today, though secrets.yaml carries an unused stale one), and pass it
# as `EnvironmentFile` with `TS_AUTHKEY=`.
#
# THE NODE MUST BE NAMED `go`, and that is a claim about the Tailscale
# admin console, not about this file. `-hostname go` below is what tsnet
# registers as, which is what makes MagicDNS answer `http://go/`. This
# tailnet renames its devices (`nire-cube` the host is `ts-cube` the
# device, fleet-wide -- tailscale.nix's trap #1), and renaming THIS one to
# `ts-go` or similar out of consistency would break the entire point of the
# service: `go/foo` would stop resolving. Leave it as `go`.
#
# STATUS: this unit FAILED its first real switch on nire-cube (2026-08-24,
# generation 13) and the fix is in the RestrictAddressFamilies comment
# below -- a missing AF_NETLINK, invisible to evaluation and to reading the
# rendered unit text back, exactly the class of defect lessons-learned.md
# §37 describes. It was written from a darwin session that cannot build an
# x86_64-linux toplevel (no remote builder -- CLAUDE.md's State section),
# shipped as "evaluates, not runtime-verified", and then broke for the one
# reason its own hardening comment claimed to be avoiding by leaving
# SystemCallFilter out. The lesson is not "harden less"; it is that a
# hardening knob you cannot exercise is untested regardless of how
# well-understood it looks.
#
# The fix itself IS runtime-verified: same binary, same knobs, run twice
# under `systemd-run --user` on the real host differing only in AF_NETLINK.
# What is still unverified as of 2026-08-24 is the authenticated node --
# that needs the one-time login below to actually be done.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);

        # StateDirectory = "golink" under DynamicUser puts the real directory
        # at /var/lib/private/golink and symlinks /var/lib/golink to it; both
        # paths work from outside, and the service only ever sees
        # /var/lib/golink. Written out rather than using systemd's `%S`
        # specifier so the two flags below read as ordinary paths.
        stateDir = "/var/lib/golink";
    in {
        flake.modules.nixos.${moduleName} = { pkgs, ... }: {
            # `pkgs` bound on the INNER NixOS module, not the outer
            # flake-parts function -- flake-parts injects no `pkgs` at that
            # scope and evaluating it errors with "attribute 'pkgs'
            # missing". Same pattern grafana.nix and zsh.nix already use.

            # Unit name written out literally, NOT derived from `moduleName`:
            # the flake-parts attribute has to track the filename (that's how
            # dirsAsCategory finds it), but the systemd unit name is what
            # `systemctl status golink` and the journal key off, and it should
            # not quietly change if this file is ever renamed.
            systemd.services.golink = {
                description = "golink -- go/ shortlinks, as its own tailnet node";
                wantedBy    = [ "multi-user.target" ];
                after       = [ "network-online.target" ];
                wants       = [ "network-online.target" ];
                # NOT after tailscaled.service -- see this file's header.
                # tsnet is its own node; the host's tunnel is irrelevant to
                # it, and ordering against it would imply a dependency that
                # doesn't exist.

                serviceConfig = {
                    # `-sqlitedb` is REQUIRED, not optional: golink.go
                    # returns "--sqlitedb is required" and exits unless
                    # `-dev-listen` is also set. `-config-dir` is where tsnet
                    # keeps the node key -- left unset it derives a path from
                    # os.UserConfigDir, which under DynamicUser (no $HOME
                    # worth relying on) is exactly the kind of implicit path
                    # that goes wrong quietly. Both pinned here.
                    ExecStart = lib.concatStringsSep " " [
                        (lib.getExe pkgs.golink)
                        "-hostname go"                      # see header: must stay `go`
                        "-sqlitedb ${stateDir}/golink.db"   # the links themselves
                        "-config-dir ${stateDir}/tsnet"     # tsnet node key + state
                    ];

                    Restart    = "on-failure";
                    RestartSec = "5s";

                    # DynamicUser rather than a declared users.users.golink:
                    # systemd owns the uid AND the state directory's
                    # ownership, which is precisely the thing that went wrong
                    # twice for grafana.nix (a secret file left root:root,
                    # unreadable by the service's own user, once by hand and
                    # once again after a hand fix regressed). Nothing here is
                    # hand-created, so there is nothing to get the ownership
                    # of wrong.
                    #
                    # Note for anyone changing this later: switching to a
                    # static user does NOT move existing state --
                    # /var/lib/private/golink would be left owned by a uid
                    # that no longer exists, and golink would come up as a
                    # brand-new, unauthenticated node with no links. Move the
                    # directory and chown it in the same change.
                    DynamicUser        = true;
                    StateDirectory     = "golink";
                    StateDirectoryMode = "0700";
                    WorkingDirectory   = stateDir;

                    # Modest hardening only, and deliberately so. DynamicUser
                    # already implies NoNewPrivileges, ProtectSystem=strict,
                    # PrivateTmp and RemoveIPC; what's added here is the
                    # handful that is obviously safe for a pure-Go network
                    # daemon with no cgo (golink's sqlite is modernc.org/
                    # sqlite, pure Go) and no device access (tsnet is
                    # userspace netstack -- it never opens /dev/net/tun).
                    # MemoryDenyWriteExecute and a SystemCallFilter are still
                    # left OUT on purpose: an untested syscall filter fails as
                    # a confusing crash at start rather than as anything
                    # diagnosable. That reasoning was right about the risk and
                    # wrong about which knob carried it -- see the next
                    # comment.
                    ProtectHome           = true;
                    ProtectKernelTunables = true;
                    ProtectKernelModules  = true;
                    ProtectControlGroups  = true;

                    # AF_NETLINK IS LOAD-BEARING. Leaving it out is what made
                    # this unit crash-loop on its first real switch
                    # (nire-cube, 2026-08-24, generation 13):
                    #
                    #   tsnet: route ip+net: netlinkrib: address family not
                    #   supported by protocol
                    #
                    # Go's `net` package enumerates interfaces and routes
                    # through a netlink socket (syscall.NetlinkRIB ->
                    # socket(AF_NETLINK, SOCK_RAW, ...)), and
                    # RestrictAddressFamilies makes a blocked socket() return
                    # EAFNOSUPPORT -- which is that message verbatim. So the
                    # error names netlink but reads like a kernel/protocol
                    # problem rather than a sandbox one, which is what makes
                    # it worth writing down: nothing in it says "systemd".
                    #
                    # Confirmed by A/B on the real host rather than reasoned
                    # about: the same golink binary under the same knobs, run
                    # twice via `systemd-run --user`, differing ONLY in this
                    # list. Without AF_NETLINK it exits 1 on that message;
                    # with it, tsnet starts and prints its auth URL. Anything
                    # tsnet-based needs this; do not "tidy" it back out.
                    RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" "AF_NETLINK" ];
                    RestrictNamespaces      = true;
                    LockPersonality         = true;
                };
            };

            # No golink-persist.nix alongside this, same reasoning
            # grafana.nix and forgejo.nix each give: cube-configuration.nix's
            # header says this host has a plain persistent root, not the
            # `/root` wipe durandal/tenacity/lego get, so /var/lib/private/
            # golink (the links database AND the tsnet node key) survives
            # reboots with no environment.persistence entry. If this module
            # is ever imported by a host that DOES wipe root, add one first,
            # modeled on tailscale-persist.nix -- otherwise every reboot
            # loses every shortlink and re-registers a fresh tailnet device.
        };
}
