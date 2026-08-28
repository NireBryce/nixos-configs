# Non-impermanence hosts (nire-cube today) have no help anywhere in this
# repo setting a login password. WARN-impermanence.nix documents the whole
# /persist dance for hosts that wipe /root on boot; a host that keeps a plain
# persistent root has no equivalent pointer, and elly-user.nix's
# `hashedPasswordFile` is unconditional -- see that file -- so on a host like
# this it silently points at a file nothing here creates.
#
# Gated the same way invariants.nix gates its impermanence-only checks: on
# `boot.initrd.systemd.services ? restore-root`, the unit only
# WARN-impermanence.nix creates. See that file's "OPT-IN: HOSTS WITHOUT
# IMPERMANENCE ARE EXEMPT" header for why that signal and not
# `environment.persistence` (declared for
# every host regardless -- nire/system/impermanence/declare-persistence-option.nix).
#
# Filed under nireUser/elly/, so it rides the `elly` category into every host
# automatically rather than being wired into a specific host's config by
# hand. Stays silent for durandal/tenacity, and fires on its own for any
# future host that also skips impermanence.
#
# A `warnings` entry, not an `assertions` failure: this can't check whether
# /persist/passwords/elly actually exists on the target machine -- that path
# is on the host being built for, not on whatever machine is evaluating this
# flake -- so it has nothing to assert. It only knows the class of host it's
# looking at, hence a standing reminder rather than a one-time check.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { config, ... }:
        let
            usesImpermanence = config.boot.initrd.systemd.services ? restore-root;
        in {
            # # description = "reminds a non-impermanence host that elly has no password until one is set by hand";
            warnings = lib.optional (!usesImpermanence) ''
                elly has no password on this host until you set one by hand. users.mutableUsers
                is false, so `passwd` will not stick -- any change made that way is reverted on
                the next switch -- and users.users.elly.hashedPasswordFile (elly-user.nix)
                expects a real hash already sitting at /persist/passwords/elly, which nothing
                in this repo creates for you.

                Generate one and put it there before switching, or elly cannot log in:

                    nix run nixpkgs#mkpasswd -- -m sha-512   # prompts for a password, prints its hash
                    sudo install -D -m600 /dev/stdin /persist/passwords/elly   # paste the hash, then Ctrl-D
            '';
        };
}
