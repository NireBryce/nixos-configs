# nire-llm-sandbox: a NixOS guest image, meant to run as a libvirt VM on
# nire-cube (see ../../nire/virtualization/virtualization-cube.nix), sandboxing
# an LLM coding agent (Claude Code) away from the real host's filesystem,
# credentials, and network identity. The VM *is* the sandbox boundary --
# everything inside it is disposable the way the host cannot be.
#
# Not a physical host, not switched-to like durandal/tenacity/cube -- a
# nixosConfigurations entry that exists to build an image (nire-installer,
# the live-USB image, was the same shape before removal 2026-08-27; see
# wiki/history.md), but this one runs *persistently* once started.
#
# Built via nixpkgs' virtualisation/disk-image.nix (imported explicitly below
# via `modulesPath`), NOT nixos/modules/image/images.nix's
# `image.modules.qemu` variant system despite that module using the same
# disk-image.nix internally. Deliberate: images.nix builds each variant as an
# ISOLATED configuration via `extendModules`, never feeding
# fileSystems/bootloader back into the base config's `system.build.toplevel`
# -- which checks.nix forces for every nixosConfigurations entry (the
# variant-based first draft failed exactly there: image evaluated fine,
# toplevel died with "the 'fileSystems' option does not specify your root
# file system", no grub.devices). Importing disk-image.nix directly (with
# image.efiSupport = false) gives fileSystems."/" AND boot.loader.grub on the
# BASE config, satisfying both the guest and the forced toplevel;
# image.filePath (declared by nixos/modules/image/file-options.nix, which
# disk-image.nix imports on its own) becomes a plain, directly-readable
# config value -- see virtualization-cube.nix, which reads it straight off
# config.flake.nixosConfigurations.nire-llm-sandbox.config.
#
# `llm-sandbox-image.nix`, next to this file, turns config.system.build.image
# into a `packages.llm-sandbox-vm` flake output for humans
# (`nix build .#llm-sandbox-vm`); virtualization-cube.nix does NOT depend on
# that package -- it reads the same underlying value directly, so exactly one
# path to this derivation, not two that have to agree.
#
# An EARLIER version used nixos-generators, deprecated in favour of exactly
# this mechanism (upstreamed into nixpkgs as of NixOS 25.05); switched the
# same day, before landing on main.
#
# No `elly` user, no Home Manager, no impermanence: a minimal, self-contained
# guest (importing `system` would pull in kdeconnect, gaming, bluetooth, a
# desktop session). ssh key list duplicated from ssh.nix rather than imported
# -- no `elly` user to hang `authorizedKeys` off of via that shared module.
# Copied from ssh.nix's list 2026-08-22; re-copy if ssh.nix's moves rather
# than letting this one drift behind it.
#
# VERIFIED FURTHER THAN "EVALUATION ONLY", 2026-08-22, but short of a real
# boot: `just modules` clean, the qcow2 was BUILT -- config.system.build.image
# produces a working 3.2GB nixos-image-qcow2-*.qcow2 at the path
# config.image.filePath names. That build caught a real bug: the first
# virtualization-cube.nix used image.filePath as if absolute; it is
# documented as relative to the image derivation's own $out, so the
# activation script checked `[ -e "nixos-image-qcow2-....qcow2" ]`, a bare
# filename that would fail under systemd. Fixed there, not here. Still
# unverified: nothing has defined this in libvirt or booted it on real
# hardware -- treat every claim about THAT as unverified until done
# (CLAUDE.md's "Treat an undated 'verified' as *evaluates*" rule is exactly
# that gap).
{ config, ... }:
    let
        # Bound out here, not in the inner module's arg list: `config` there
        # would silently mean the *NixOS* config, not this flake-parts one.
        # See CLAUDE.md, "There are two different `config`s, and they shadow".
        nixCategory = config.flake.modules.nixos.nix;
    in {
        flake.modules.nixos.llmSandboxConfiguration = { lib, pkgs, modulesPath, ... }: {
            imports = [
                nixCategory # flakes + nix-command + allowUnfree
                (modulesPath + "/virtualisation/disk-image.nix")
            ];

            # Legacy/BIOS boot (SeaBIOS, GRUB targeting /dev/vda), not UEFI --
            # matches VMs/_lib/libvirt-vm.nix's domain XML (no <loader>,
            # machine='pc'). Same override image.modules.qemu makes
            # internally; set directly since this file imports
            # disk-image.nix itself.
            image.efiSupport = false;

            networking.hostName = "nire-llm-sandbox";
            nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

            # Fresh install, not inherited state: unlike cube's pin (must
            # match what an already-installed machine committed to), this
            # guest never existed, so it pins to this flake's current release
            # the ordinary way.
            system.stateVersion = "26.11"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion

            # Read by disk-image.nix when building the qemu image. 20 GiB: a
            # NixOS closure plus git checkouts and node_modules, nowhere near
            # a real workstation.
            virtualisation.diskSize = 20 * 1024;

            networking.useDHCP = lib.mkDefault true;
            # NixOS' own firewall default (mkDefault true, from nixpkgs
            # itself) is still on here even though this guest never imports
            # nire/system/networking/networking.nix -- so 22 must be opened
            # explicitly or ssh is unreachable regardless of sshd.
            networking.firewall.allowedTCPPorts = [ 22 ];

            services.openssh = {
                enable = true;
                settings.PasswordAuthentication = false;
            };

            # `agent`, not `elly`: the account the sandboxed LLM agent runs
            # as, able to install packages / run arbitrary commands without
            # being asked -- the whole point of the VM being the isolation
            # boundary instead of a per-command permission prompt. NOPASSWD
            # sudo is fine here in a way it never would be on a real host:
            # nothing this account can do escapes the VM.
            users.users.agent = {
                isNormalUser = true;
                extraGroups  = [ "wheel" ];
                openssh.authorizedKeys.keys = [
                    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILk2lST7kOSRlanAKhl42b9IQib1hzrbxlR5pve/X37D elly@nire-lysithea"
                    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIACfyClu9egyamrth/SspY6wPA78o8sJuSR7jyBX42ex elly@nire-lysithea.local"
                    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL0sEOPmravXojxuKqN3XwplTbuz2p36UDTxmUthktnX elly@durandal"
                    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII/CCC9LRJdjqLqq5t1a0wN1cbw2fmxs2Yxi1grl/nRw elly@nire-sif"
                    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFrut9Gg3TR5omT4yWXBQhifKh6ksT46FWTYA1Gj9YpJ u0_a377@localhost"
                    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJFTe27f8e8B4DpqQYHFK7I7Pg3ZK12W7LqIrdI+ChI1 elly@nire-galatea"
                    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILqzV9o32OsJdkCfDJhR5X4uSu1nzRzrL/2gBWLp9QyX elly@nire-cube"
                    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFFfyxNzG07CdeNEZof+l49+fqx+2E79gmYvnRqiGdNp elly@nire-tenacity"
                ];
            };
            security.sudo.extraRules = [{
                users = [ "agent" ];
                commands = [{ command = "ALL"; options = [ "NOPASSWD" ]; }];
            }];

            environment.systemPackages = with pkgs; [
                claude-code # same package nirePackages/development/tools/ai-tools/claude.nix
                            # installs fleet-wide via HM; referenced directly
                            # since this guest has no HM at all.
                git
                nodejs
                ripgrep
                curl
                vim
            ];
        };
}
