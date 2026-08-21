{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { pkgs, ... }: {
            # # description = "libvirt/QEMU virtual machines, and virt-manager to drive them";

            # Was `virtualization.nix`, declaring `flake.modules.nixos.virtualization`,
            # for about an hour on 2026-08-21. It could not keep that name once these
            # modules moved into a category directory called `virtualization/`: the
            # category aggregate takes the directory's name, so file and category
            # would both have declared `flake.modules.nixos.virtualization` and
            # *merged* rather than collided -- the `boot` trap from CLAUDE.md, in a
            # shape where the merge would have been invisible because importing
            # either name would still have produced working VMs.
            #
            # `virtualization` is now the category you import in a host config, and
            # `libvirt` is this file. That is also the more honest filename: what is
            # below is libvirtd options and nothing else.
            #
            # Scope: NOT every host. This category is imported by durandal, cube and
            # testbed -- see their nireHost/*-configuration.nix -- and deliberately
            # not by tenacity or lego, which are the handhelds (they are the two that
            # import `jovian`). libvirtd is a boot-time daemon and a gamescope
            # handheld will never open virt-manager. Before 2026-08-21 these modules
            # lived under `nire/system/`, which every Linux host imports whole, so
            # they did land on the handhelds; moving them to their own category is
            # what fixed that. A new host opts in by adding `virtualization` to its
            # list, which is also where the polkit note at the bottom of this file
            # becomes relevant.
            virtualisation.libvirtd = {
                enable = true;

                qemu = {
                    # Emulated TPM, which Windows 11 guests refuse to install without.
                    swtpm.enable = true;

                    # Do NOT add `ovmf` here. Every guide still says to, and the
                    # option is gone: nixpkgs removed the whole
                    # `virtualisation.libvirtd.qemu.ovmf` submodule and now ships
                    # every OVMF image QEMU distributes by default. Setting it is
                    # not ignored -- libvirtd.nix asserts on it and evaluation
                    # fails with "the submodule has been removed". Same for the
                    # older `qemuOvmf`/`qemuOvmfPackage`, which are
                    # mkRemovedOptionModule.

                    # virtiofs shares between host and guest. libvirt looks for the
                    # helper binary in this list; without it a <filesystem
                    # type='mount' driver='virtiofs'> device fails to start.
                    vhostUserPackages = with pkgs; [ virtiofsd ];
                };
            };

            # Sets up the dconf entry that points virt-manager at qemu:///system on
            # first launch, which is otherwise a manual step every fresh /home.
            # It also installs the package, so don't list virt-manager in
            # virt-tools.nix as well. programs.dconf is already enabled by the
            # desktop, so it is not restated here.
            programs.virt-manager.enable = true;

            # USB passthrough from the host into a running guest, via the
            # spice-client-glib udev rules and the usbredir helper. virt-manager's
            # "Redirect USB device" menu does nothing without it.
            virtualisation.spiceUSBRedirection.enable = true;

            # elly needs to be in `libvirtd` to reach qemu:///system without
            # authenticating for every action. Declared here rather than in
            # nireUser/elly/user-settings/elly-user.nix on purpose: extraGroups
            # concatenates across modules instead of overriding, so naming a group
            # in two files puts it in the list twice -- which is exactly what
            # happened with "podman", see containers.nix. The group itself is
            # created by the libvirtd module above, so this module owns both ends.
            users.users.elly.extraGroups = [ "libvirtd" ];

            # libvirtd's assertion requires polkit; it is already on via the
            # desktop on every host here, so this is a note rather than a setting.
            # If a headless host ever imports this, it needs
            # security.polkit.enable = true or evaluation fails with
            # "The libvirtd module currently requires Polkit to be enabled".
        };
}
