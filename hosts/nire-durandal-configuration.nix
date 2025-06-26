{ 
    import-tree,
    ... 
}:

{
    imports = [
        # (util.importRecurseDirectories ./nire-durandal)
        (import-tree ./nire-durandal)
        (import-tree ../system-config/users/elly)
        (import-tree ../system-config/hw/gpu/amd)
        (import-tree ../system-config/hw/cpu/amd)
        (import-tree ../system-config/common)
        (import-tree ../system-config/gaming)
        (import-tree ../system-config/wm/kde)

    # impermanence
    # ____________________________________________________ 
    # |- /!!\ WARN: this will delete /root on boot /!!\ -|
    # ----------------------------------------------------
    ../system-config/impermanence/_WARN.impermanence.nix
    
    
];
    system.stateVersion = "23.11"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
    networking.hostName = "nire-durandal";
}
