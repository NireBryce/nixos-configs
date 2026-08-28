# nire-llm-sandbox: a NixOS guest image, meant to run as a libvirt VM on
# nire-cube (see ../../nire/virtualization/virtualization-cube.nix), sandboxing
# an LLM coding agent (Claude Code) away from the real host's filesystem,
# credentials, and network identity. The VM *is* the sandbox boundary --
# everything inside it can be treated as disposable the way the host cannot.
#
# Not a physical host and not switched-to like durandal/tenacity/cube --
# a nixosConfigurations entry that exists to build an image, not to be
# deployed to hardware directly (nire-installer, the live-USB image, was the
# same shape before its removal 2026-08-27; see wiki/history.md). Unlike a
# live-USB installer image though, this one is meant to run *persistently*
# once started, not booted once and discarded.
#
# Built as a qcow2 disk image via nixpkgs' own virtualisation/disk-image.nix
# (imported explicitly below via `modulesPath`, the same mechanism a live-ISO
# profile uses) -- NOT via
# nixos/modules/image/images.nix's `image.modules.qemu` "variant" system,
# despite that module using this exact same disk-image.nix internally.
# Deliberately bypassed: images.nix builds each variant as an ISOLATED
# configuration via `extendModules`, which never feeds fileSystems/bootloader
# back into the base config's own `system.build.toplevel` -- and checks.nix
# forces exactly that toplevel for every nixosConfigurations entry now that
# this one exists. Confirmed the hard way, not assumed: the variant-based
# first draft of this file evaluated the image fine but failed
# `system.build.toplevel` itself with "the 'fileSystems' option does not
# specify your root file system" and no grub.devices set. Importing
# disk-image.nix directly (setting image.efiSupport = false, same override
# the "qemu" variant makes internally) gives fileSystems."/" AND
# boot.loader.grub on the BASE config too, so both the guest itself and
# `just modules`/checks.nix's forced toplevel are satisfied. `image.filePath`
# (declared by nixos/modules/image/file-options.nix, which disk-image.nix
# imports on its own) becomes a plain, directly-readable config value this
# way too -- see virtualization-cube.nix, which reads it straight off
# config.flake.nixosConfigurations.nire-llm-sandbox.config rather than
# through any packages/flake-output indirection.
#
# `llm-sandbox-image.nix`, right next to this file, turns
# config.system.build.image into a `packages.llm-sandbox-vm` flake output
# for humans (`nix build .#llm-sandbox-vm`) -- but virtualization-cube.nix
# does NOT depend on that package; it reads the same underlying value
# directly, so there is exactly one path to this derivation, not two that
# have to agree.
#
# An EARLIER version of this file used nixos-generators (a third-party flake
# input) for the same job, before its own eval output turned out to say it's
# deprecated in favour of exactly this mechanism -- upstreamed into nixpkgs
# as of NixOS 25.05. Switched the same day, before ever landing on main.
#
# No `elly` user, no Home Manager, no impermanence: a minimal, self-contained
# guest, not a member of the fleet's shared `elly`/`system` conventions
# (importing `system` would also pull in things this guest has no business
# with -- kdeconnect, gaming, bluetooth, a desktop session). ssh key list
# duplicated from ssh.nix rather than imported, for the same reason: there is
# no `elly` user here to hang `authorizedKeys` off of via that shared module.
# Copied from ssh.nix's CURRENT list as of 2026-08-22 -- re-copy if ssh.nix's
# list moves on, rather than letting this one silently drift behind it.
#
# VERIFIED FURTHER THAN "EVALUATION ONLY", 2026-08-22, but still short of a
# real boot: `just modules` is clean, and the actual qcow2 was BUILT (not
# just evaluated) -- config.system.build.image really produces a working
# 3.2GB nixos-image-qcow2-*.qcow2 at the exact path config.image.filePath
# names. That build is also what caught a real bug: the first version of
# virtualization-cube.nix used image.filePath directly as if it were already
# absolute, when it is documented as relative to the image derivation's own
# $out -- the built activation script was checking `[ -e
# "nixos-image-qcow2-....qcow2" ]`, a bare filename that would have failed
# under systemd every time. Fixed there, not here. What's still unverified:
# nothing has defined this in libvirt or booted it on real hardware. Treat
# every claim about THAT as unverified until it's been done -- see
# CLAUDE.md's "Treat an undated 'verified' as *evaluates*" rule, which is
# exactly the gap between a successful build and a real boot.
{ config, ... }:
    let
        # Bound out here rather than added to the inner module's own arg list:
        # the inner module below takes its own `lib`/`pkgs`, and if `config`
        # were added to that list too it would
        # silently start meaning the *NixOS* config instead of this
        # flake-parts one. See CLAUDE.md, "There are two different `config`s,
        # and they shadow".
        nixCategory = config.flake.modules.nixos.nix;
    in {
        flake.modules.nixos.llmSandboxConfiguration = { lib, pkgs, modulesPath, ... }: {
            imports = [
                nixCategory # flakes + nix-command + allowUnfree
                (modulesPath + "/virtualisation/disk-image.nix")
            ];

            # Legacy/BIOS boot (SeaBIOS, GRUB targeting /dev/vda), not UEFI --
            # matches VMs/_lib/libvirt-vm.nix's domain XML, which sets no
            # <loader> and uses machine='pc'. Same override
            # image.modules.qemu makes internally; set directly here since
            # this file imports disk-image.nix itself rather than going
            # through that variant.
            image.efiSupport = false;

            networking.hostName = "nire-llm-sandbox";
            nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

            # Fresh install, not inherited state -- unlike cube's stateVersion
            # pin (which has to match what a real, already-installed machine
            # committed to before this flake ever pointed at it), this guest
            # has never existed before, so it pins to this flake's own
            # current release the ordinary way, not something read off a
            # real disk.
            system.stateVersion = "26.11"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion

            # Read by nixos/modules/virtualisation/disk-image.nix when
            # building the qemu image variant. 20 GiB: comfortable for a
            # NixOS closure plus git checkouts and node_modules, nowhere near
            # what a real workstation needs.
            virtualisation.diskSize = 20 * 1024;

            networking.useDHCP = lib.mkDefault true;
            # NixOS' own firewall default (mkDefault true, from nixpkgs
            # itself, independent of anything this repo restates elsewhere)
            # is still on here even though this guest never imports
            # nire/system/networking/networking.nix -- so 22 has to be
            # opened explicitly or ssh is unreachable regardless of what
            # sshd itself is doing.
            networking.firewall.allowedTCPPorts = [ 22 ];

            services.openssh = {
                enable = true;
                settings.PasswordAuthentication = false;
            };

            # `agent`, not `elly`: this is the account the sandboxed LLM
            # agent actually runs as, and it needs to install packages / run
            # arbitrary commands inside the guest without being asked --
            # that is the whole point of the VM being the isolation boundary
            # instead of a per-command permission prompt. NOPASSWD sudo is
            # fine here in a way it would never be on a real host: nothing
            # this account can do escapes the VM.
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
                            # installs fleet-wide via Home Manager; referenced
                            # directly here since this guest has no HM at all.
                git
                nodejs
                ripgrep
                curl
                vim
            ];
        };
}
