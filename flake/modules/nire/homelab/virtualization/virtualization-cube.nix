# Cube-only addition to `virtualization`, NOT a member of the category itself
# -- load-bearing, not a style choice.
#
# Sits bare in nire/virtualization/, deliberately not inside VMs/ or any
# other subdirectory: dirsAsCategory only collects from *sub*directories, so
# a .nix file directly in a category directory is collected by nothing
# (flake/doc/dirsAsCategory.md, CLAUDE.md). This file never becomes part of
# `flake.modules.nixos.virtualization`; importing `virtualization` (durandal
# and cube both do) does not reach it -- only importing `virtualization-cube`
# by name does, one line in cube-configuration.nix.
#
# Opposite placement from VMs/_lib/libvirt-vm.nix (the generator this file
# calls), under `_lib/` because it is a plain function import-tree cannot
# handle, not to exclude it from the aggregate -- see that file's header,
# including why VMs/ itself is a real subdirectory.
#
# Verified further than plain evaluation, as of 2026-08-22 -- see
# llm-sandbox-configuration.nix's header for what that does and doesn't
# cover. Still short of a real libvirt define/boot on hardware.
{ config, lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);

        # The guest's own evaluated config, read directly rather than through
        # any packages/flake-output indirection -- see
        # llm-sandbox-configuration.nix's header for why. `image` and
        # `imagePath` both come off this one value, so they can never
        # disagree.
        sandboxCfg = config.flake.nixosConfigurations.nire-llm-sandbox.config;
    in {
        flake.modules.nixos.${moduleName} =
            import ./VMs/_lib/libvirt-vm.nix {
                name  = "llm-sandbox";

                # The UUID libvirt itself assigned when `virsh define` first
                # succeeded on nire-cube, 2026-08-23 -- adopted, not a fresh
                # `uuidgen`, because the domain was already running under it
                # (see libvirt-vm.nix on the `uuid` parameter for why one is
                # required); a new UUID here would re-fire the same
                # define-conflict on the next switch, against the guest
                # that's already running.
                uuid  = "4da8f257-fad8-4670-ab2d-7577ca94d5ed";

                image = sandboxCfg.system.build.image;

                # NOT just sandboxCfg.image.filePath -- that option is
                # documented as relative to the image derivation's own $out,
                # not an absolute in-store path by itself. Used bare it
                # produced an activation script checking
                # `[ -e "nixos-image-qcow2-....qcow2" ]` (a bare filename,
                # cwd-relative, certain to fail under systemd).
                # `${...}/${...}` here is what combines them.
                imagePath = "${sandboxCfg.system.build.image}/${sandboxCfg.image.filePath}";

                memoryMB  = 4096;
                vcpus     = 2;

                # NAT internet access. See libvirt-vm.nix's parameter
                # comment: not only a security knob -- the agent inside needs
                # network to reach Claude's API at all, so `false` gives a VM
                # that boots but can't do the one thing it exists for. Left
                # toggleable (not hardcoded into the generator): the
                # isolation/functionality tradeoff is a real, live decision.
                networked = true;

                # SSH in from off-host, tailnet only -- NOT LAN too. Added
                # 2026-08-23; the guest side was already ready
                # (llm-sandbox-configuration.nix has had openssh and elly's
                # keys from the start); this opens the path in.
                # `sourceCidrs = tailnetOnlyCidrs` overrides libvirt-vm.nix's
                # default (LAN-or-tailnet) down to tailnet-only, deliberate
                # for this VM -- not a property of the generator. `10` and
                # `2222` are the generator's first real allocation; a second
                # VM wanting sshForward needs its own `guestId` (no
                # auto-allocator -- see libvirt-vm.nix's parameter comment)
                # and `hostPort`.
                sshForward = {
                    guestId     = 10;
                    hostPort    = 2222;
                    sourceCidrs = [ "100.64.0.0/10" ]; # tailnetOnlyCidrs, inlined:
                                                        # no `let` binding here
                                                        # reaches into
                                                        # libvirt-vm.nix's
                                                        # internals to name it.
                };
            };
}
