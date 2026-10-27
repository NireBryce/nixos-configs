# This is a dirs-as-categories module, which means it creates a flake-parts
# module that derives its name from its filename minus the .nix suffix, whose
# category module is the name of the folder it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki

# summary: What nire-lysithea is made of. M3 MacBook Air, aarch64-darwin.
#
# Sits directly under host-config/ rather than in a category directory, same
# reason as durandal-configuration.nix and tenacity-configuration.nix:
# a file directly in an area belongs to no category, so a host definition
# should not become a member of anything.
#
# First real darwin host in this config. Reuses the SAME shared categories the
# NixOS hosts import; safe to do broadly because a category's darwin module
# only ever contains modules that have a `darwin` key -- including `system`,
# for instance, does not drag in bluetooth/networking/kdeconnect/etc, because
# none of those have one. See wiki/module-files.md.
#
# What actually brings packages and dotfiles across is
# enable-home-manager-darwin.nix (in `system`), which wires
# home-manager.users.elly to the SAME `elly-home-manager` aggregate the NixOS
# hosts use -- not a lysithea-specific copy. Whatever in that aggregate does
# not evaluate on aarch64-darwin needs excluding at the source, not forked
# here.
{
    includes.darwin = [
        # ── this machine ────────────────────────────────────────────────────────
        # host-config/lysithea/: nixpkgs-hostPlatform-lysithea, nixpkgs-stateVersion-lysithea
        # -- suffixed 2026-08-12 for consistency with durandal/tenacity, though
        # darwin is its own module class here, so nothing would actually have
        # collided yet.
        "lysithea"

        # ── shared ───────────────────────────────────────────────────────────────
        "nix"           # basic-nix-settings: allowUnfree, experimental-features
        "system"        # enable-home-manager-darwin -- this is what brings
                        # packages and dotfiles in, via elly-home-manager

        # ── macOS ────────────────────────────────────────────────────────────────
        # homebrew, shell registration, system.primaryUser/nix.enable. Not
        # `desktop-env` or `hardware` or `peripherals` -- none of those declare
        # anything darwin-class, so importing them would resolve to empty
        # aggregates and add nothing. Left out rather than imported-for-nothing.
        "macos"

        # ── user ─────────────────────────────────────────────────────────────────
        "elly"          # elly-user (darwin fonts), elly-git (homeManager,
                        # reused via elly-home-manager already -- listed here too
                        # only because durandal/tenacity list it the same way)
    ];

    darwin.networking.hostName = "nire-lysithea";
}
