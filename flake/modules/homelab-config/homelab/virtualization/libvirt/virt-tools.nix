# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    nixos = { pkgs, ... }: {
        # summary: client and disk-image tooling for the VMs libvirt.nix hosts

        # Split from libvirt.nix so that file stays about the daemon and its
        # options. Nothing here configures libvirtd; it is all things you run
        # against it.
        #
        # `libvirt` and `qemu` themselves are deliberately absent: the libvirtd
        # module already puts cfg.package and cfg.qemu.package into
        # environment.systemPackages, so `virsh` and `qemu-img` are on PATH
        # already and listing them here would pin a second copy. `spice-gtk` is
        # out for the same reason -- virtualisation.spiceUSBRedirection in
        # libvirt.nix installs it, for the polkit actions that go with the
        # setuid spice-client-glib-usb-acl-helper wrapper.
        environment.systemPackages = with pkgs; [
            virt-viewer     # standalone SPICE/VNC console, no virt-manager needed
            virt-top        # top(1) for domains
            # TEMPORARY -- listed in
            # wiki/upkeep-and-admin/temporary-patches-and-hacks.md.
            # guestfs-tools (virt-cat, virt-df, virt-sysprep, virt-customize)
            # and libguestfs (guestfish, and the library they are built on)
            # are off while nixpkgs marks libguestfs broken: with them listed,
            # nire-cube does not evaluate. Restore both, and delete this
            # comment, once the cube toplevel evaluates with them back.
            quickemu        # throwaway VMs from a one-line spec, outside libvirt

            # Windows guest paravirt drivers, as an ISO to attach at install
            # time -- storage and network in a Windows guest are unusably slow
            # or absent until they are loaded. Unfree; allowUnfree is already
            # set system-side in basic-nix-settings.nix.
            virtio-win
        ];
    };
}
