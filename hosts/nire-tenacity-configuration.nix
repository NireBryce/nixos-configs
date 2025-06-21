{
    # inputs,
    import-tree,
    ...
}:
{
    imports = [
        (import-tree ./nire-tenacity)
        (import-tree ../system-config/users/elly)
        (import-tree ../system-config/hw/gpu/amd)
        (import-tree ../system-config/hw/cpu/amd)
        (import-tree ../system-config/common)
        (import-tree ../system-config/gaming)
        (import-tree ../system-config/wm/gaming-handheld)


        # impermanence
        # ____________________________________________________ 
        # |- /!!\ WARN: this will delete /root on boot /!!\ -|
        # ----------------------------------------------------
        ../system-config/impermanence/_WARN.impermanence.nix
    ];

    system.stateVersion = "25.05"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
    networking.hostName = "nire-tenacity";
}
