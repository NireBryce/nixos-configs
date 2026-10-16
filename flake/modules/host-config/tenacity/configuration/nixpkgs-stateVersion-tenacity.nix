# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    # 25.05, not durandal's 23.11 -- this host was installed later. The
    # sibling branch's tenacity stub said 23.11, which looks like it was
    # copied from durandal; the pre-restructure config that actually ran
    # on this machine (origin/backup-before-flake-parts-happened) says
    # 25.05.
    #
    # Plain assignment, not lib.mkDefault like durandal/lysithea's
    # equivalents -- carried over as-is from tenacity-configuration.nix
    # rather than normalized, since nothing else in the tree sets this for
    # tenacity and changing priority wasn't asked for.
    nixos = {
        system.stateVersion = "25.05"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
    };
}
