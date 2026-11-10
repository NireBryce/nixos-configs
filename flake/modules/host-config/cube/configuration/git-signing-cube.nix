# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki

# summary: nire-cube signs commits with its own passphrase-protected key file
# and prompts for the passphrase, instead of asking a Bitwarden-served agent.
#
# elly-git.nix sets `signing.key` to a PUBLIC key literal. Git hands that to
# `ssh-keygen -Y sign`, which then asks an SSH agent for the matching private
# half. durandal and tenacity have one (the Bitwarden desktop app's agent,
# wired up by bash.nix/zsh.nix); cube has no desktop app and no agent, so a
# commit there fails with `error: Couldn't get agent socket?`.
#
# Pointing `signing.key` at a PRIVATE key file instead makes ssh-keygen load
# that file itself and ask for its passphrase on the terminal. No agent is
# involved. git(1) documents this for `user.signingKey`: "path to your private
# ssh key or the public key when ssh-agent is used".
#
# The key is cube's own ~/.ssh/id_ed25519, not the key Bitwarden serves.
# Commits it signs show as verified on GitHub only if its public half is
# registered there as a signing key (Settings > SSH and GPG keys > New SSH
# key > Key type: Signing Key). That is an account setting, not something this
# repo can do.
#
# The path is the literal user's home, like the other hardcoded `elly` uses
# (.agents/rules/flake-modules.md).
{
    nixos = { lib, ... }: {
        home-manager.users.elly.programs.git.signing.key =
            lib.mkForce "/home/elly/.ssh/id_ed25519";
    };
}
