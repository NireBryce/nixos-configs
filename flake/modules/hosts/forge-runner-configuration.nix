# The Forgejo Actions runner VM -- a NixOS guest on nire-cube, instantiated
# by virtualization-cube.nix through VMs/_lib/libvirt-vm.nix. This file is
# the guest's whole config; cube-side support (the sops secret, the share
# staging, the registration against the forge) lives in
# git-forge/forgejo/actions-runner.nix.
#
# Why a VM at all: a CI runner executes workflow code, and workflow code on
# a runner with podman/docker access is one container escape away from the
# host. On cube that escape would land root access to everything sops
# decrypts there; in here it lands a disposable-ish VM that holds exactly
# one secret (its own runner token) -- GitHub's ephemeral-runner model,
# minus the ephemerality.
#
# The guest deliberately runs NO sops-nix, no Home Manager, and no user
# account -- same shape llm-sandbox used. Its one secret arrives over
# virtiofs (tag `runner-secret`, mounted read-only at /mnt/runner-secret)
# from cube's already-decrypted /run/secrets copy; the mount is the guest's
# entire trust surface from the host side, and the runner token is the only
# thing that crosses.
#
# Networking, without tailscaled: the guest is NOT on the tailnet. It
# reaches the forge through Caddy on the virbr0 gateway (192.168.122.1),
# which vm-networking.nix already trusts and whose cert for
# git.moose-micro.ts.net is a real publicly-trusted one -- so the
# connection URL is the ordinary ROOT_URL and TLS validates against system
# CAs. The /etc/hosts pin below is what makes the name resolve at all
# (MagicDNS only answers tailnet members). Forgejo's own 127.0.0.1:3001
# listener stays unreachable from here, by design -- Caddy is the door.
{ lib, ... }:
{
    flake.modules.nixos.forgeRunnerConfiguration = { pkgs, modulesPath, ... }: {
        imports = [
            # DIRECT import, not image.modules -- the image.modules variant
            # builds an extendModules config that never feeds fileSystems/
            # bootloader back into the base config, and checks.nix's forced
            # toplevel dies with "the 'fileSystems' option does not specify
            # your root file system" (lessons-learned §36).
            (modulesPath + "/virtualisation/disk-image.nix")
        ];

        # SeaBIOS/BIOS, matching the generator's machine='pc' domain XML.
        image.efiSupport = false;

        nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
        system.stateVersion  = "26.11";

        # CI jobs get disk too -- builds, images, node_modules. qcow2 is
        # sparse; 30G virtual costs nothing until used.
        virtualisation.diskSize = 30 * 1024;

        networking = {
            # No `nire-` prefix: that prefix names the fleet machines
            # (hosts.nix explains); this is a component of cube.
            hostName = "forge-runner";
            useDHCP  = lib.mkDefault true;
            firewall.allowedTCPPorts = [ 22 ];
            hosts = {
                # The forge, via Caddy on the virbr0 gateway. WITHOUT this
                # pin the name is unresolvable from the guest (MagicDNS
                # doesn't serve non-tailnet members) and the runner would
                # sit in DNS-retry loops. SNI still matches -- this is a
                # hosts-file trick, not a TLS shortcut.
                "192.168.122.1" = [ "git.moose-micro.ts.net" ];
            };
        };

        # virtiofs share of the runner token, read-only. systemd loads the
        # module and the mount unit comes from the fileSystems entry; the
        # runner unit below is ordered after it via RequiresMountsFor.
        boot.kernelModules = [ "virtiofs" ];

        # Eyes on the guest. The generator wires a serial console (pty),
        # but the base image's kernel only talks to VGA unless told
        # otherwise -- without this, a guest that fails to boot fails
        # SILENTLY from the host's `virsh console` (hit on first boot
        # 2026-09-25: guest running, no DHCP lease, vnet1 tx_packets=0,
        # console dark).
        boot.kernelParams = [ "console=ttyS0,115200n8" ];
        fileSystems."/mnt/runner-secret" = {
            device  = "runner-secret";
            fsType  = "virtiofs";
            options = [ "ro" "nodev" "nosuid" ];
        };

        # The guest's own podman, for docker-executor jobs. Self-contained:
        # the docker socket this enables is the GUEST's, not cube's -- on
        # cube that option is deliberately absent (see podman.nix's note).
        virtualisation.podman = {
            enable              = true;
            dockerCompat        = true;
            dockerSocket.enable = true;
        };

        nix.settings.experimental-features = [ "nix-command" "flakes" ];

        services.forgejo-runner.instances.forge-runner = {
            enable = true;

            settings = {
                runner = {
                    # Same labels as the runner had when it lived on cube:
                    # GitHub-style names over the guest's own podman, and a
                    # host executor -- `nix:host` now means this VM's host,
                    # i.e. nix builds happen in the VM, not on cube.
                    labels = [
                        "ubuntu-latest:docker://node:24-bookworm"
                        "ubuntu-24.04:docker://node:24-bookworm"
                        "nix:host"
                    ];
                };

                server.connections.default = {
                    url = "https://git.moose-micro.ts.net/";

                    # Pinned 2026-09-25, derived from forgejo-runner-secret
                    # (the pairing the forge enforces: first 16 secret chars
                    # as ASCII bytes, google/uuid.FromBytes -- see the cube
                    # module's header for why this cannot ride the same
                    # secrets mechanism as the token).
                    uuid = "30343634-3961-3333-6665-303732653263";
                };
            };

            # The token, over the virtiofs share. nixpkgs renders this as
            # `token_url: file:$CREDENTIALS_DIRECTORY/...` + a
            # LoadCredential of this path, so the value never enters a
            # store path or the guest's config.yaml.
            secrets.server.connections.default.token_url =
                "/mnt/runner-secret/forgejo-runner-secret";

            # `nix:host` jobs get the VM's nix; default list restated (the
            # option replaces, not appends).
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

        # The runner unit must not start before its credential source is
        # mounted; LoadCredential on a not-yet-mounted path is a hard
        # start failure, and the mount is NOT implicitly ordered before
        # an unrelated service.
        #
        # TRAP: the unit name escapes the instance name -- nixpkgs runs it
        # through utils.escapeSystemdPath, which turns the dash into a
        # literal `\x2d`, so the unit is "forgejo-runner-forge\x2drunner"
        # and targeting the plain "forge-runner" spelling silently creates
        # an EMPTY second unit (caught by reading the rendered unit, not
        # by eval).
        systemd.services."forgejo-runner-forge\\x2drunner".unitConfig.RequiresMountsFor =
            "/mnt/runner-secret";

        # SSH for debugging a headless worker VM (the serial console is the
        # other way, and it is no fun). Reaches the guest through the
        # generator's sshForward DNAT: host port 2223, tailnet-only, to
        # 192.168.122.11:22 -- `ssh -p 2223 root@<cube>`.
        services.openssh = {
            enable = true;
            settings.PasswordAuthentication = false;
        };
        users.users.root.openssh.authorizedKeys.keys = [
            # Duplicated from system/ssh/ssh.nix rather than shared: the
            # guest imports no repo category (importing `system` would pull
            # in tailscaled, sops and the rest, none of which a runner VM
            # wants). Keep the two lists in step, with ONE deliberate
            # exception: the bare `elly@nire-lysithea` key is NOT here --
            # ssh.nix documents it as having no known private half, and a
            # new root login should not be backed by a key nobody can
            # account for. Everything below has a known owner.
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIACfyClu9egyamrth/SspY6wPA78o8sJuSR7jyBX42ex elly@nire-lysithea.local"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL0sEOPmravXojxuKqN3XwplTbuz2p36UDTxmUthktnX elly@durandal"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII/CCC9LRJdjqLqq5t1a0wN1cbw2fmxs2Yxi1grl/nRw elly@nire-sif"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFrut9Gg3TR5omT4yWXBQhifKh6ksT46FWTYA1Gj9YpJ u0_a377@localhost"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJFTe27f8e8B4DpqQYHFK7I7Pg3ZK12W7LqIrdI+ChI1 elly@nire-galatea"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILqzV9o32OsJdkCfDJhR5X4uSu1nzRzrL/2gBWLp9QyX elly@nire-cube"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFFfyxNzG07CdeNEZof+l49+fqx+2E79gmYvnRqiGdNp elly@nire-tenacity"
            "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBFwOpjlybwn/ebH4KKoAcsVQ41wxeqD41CyfIALkV61t8BXV2Wf2pdnrBMxLuHHi9+uq7DlGs2nrW938WtaHvRo= elly@deja"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMbt2aSZdU5732g4yNXo/pOnl2DZDMKKP4cPPHyAcIkF elly@nire-iona-termius"
        ];
    };
}
