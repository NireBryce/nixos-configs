# Gates on what a NixOS host does with /persist. Used by the *-persist.nix
# modules and by invariants.nix / WARN-password-required.nix, which all used to
# spell the gate out. The reasoning for the signal is in
# general-config/system/networking/tailscale-persist.nix and invariants.nix's
# "OPT-IN: HOSTS WITHOUT IMPERMANENCE ARE EXEMPT" header.
#
# NixOS only. `environment.persistence` is a NixOS option, so a darwin host or a
# bare Home Manager config never reaches these: a module that calls them is a
# `nixos` class part, and only NixOS hosts include those.
{ lib }:
rec {
    # True on a host that opted into impermanence: restore-root is the initrd
    # unit only WARN-impermanence.nix creates, so this is false on nire-cube.
    usesImpermanence = config:
        config.boot.initrd.systemd.services ? restore-root;

    # True on a host with a /persist volume to put things on, wiped or not.
    # nire-cube has one and wipes nothing. It is an option rather than a read of
    # `config.fileSystems ? "/persist"` because environment.persistence adds
    # fileSystems entries: testing for one from inside the persistence value is
    # infinite recursion. Set in general-config/system/persistence/
    # declare-persistence-option.nix (default: usesImpermanence).
    hasPersistVolume = config: config.nire.hasPersistVolume;

    persistEntries = entries: { environment.persistence."/persist" = entries; };

    # Entries only on an impermanence host. For state that a root wipe destroys
    # and nothing else keeps: on a persistent root the bind mount would rescue
    # nothing, and any persistence entry at all makes impermanence warn that
    # /var/lib/nixos is not persisted.
    #   persistIfImpermanent config { directories = [ "/var/lib/foo" ]; }
    persistIfImpermanent = config: entries:
        lib.mkIf (usesImpermanence config) (persistEntries entries);

    # Entries on any host with a /persist volume. For a folder that should live
    # on /persist whether or not root is wiped. On a host with a persistent
    # root this still trips the /var/lib/nixos warning above, so the caller
    # owns that.
    persistRegardless = config: entries:
        lib.mkIf (hasPersistVolume config) (persistEntries entries);
}
