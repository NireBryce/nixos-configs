{
    import-tree
    ...
}:
{
    imports = [
        #users
        (import-tree ./system-config/users/elly)
        
        # hardware
        (import-tree ../system-config/hw/gpu/amd)
        (import-tree ../system-config/hw/cpu/amd)
        
        # system-config
        (import-tree ../system-config/common)
        (import-tree ../system-config/gaming)

        # wm
        (import-tree ./system-config/wm/kde)
        
        # misc
        (import-tree ../___modules/linux-crisis-utilities.nix)

        # impermanence
        # ____________________________________________________ 
        # |- /!!\ WARN: this will delete /root on boot /!!\ -|
        # ----------------------------------------------------
        ../system-config/impermanence/_WARN.impermanence.nix
    ];

    
    
    
    #? This determines what to add to /run/current-system/sw, generally defined elsewhere
    environment.pathsToLink = [

    ];
}
