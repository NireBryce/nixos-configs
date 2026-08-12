# What nire-lysithea is made of. M3 MacBook Air, aarch64-darwin.
#
# Sits directly under nireHost/ rather than in a category directory, same
# reason as durandal-configuration.nix and tenacity-configuration.nix:
# dirsAsCategory only collects from *sub*directories, so a host definition
# should not become a member of anything.
#
# First real darwin host in this config. Reuses the SAME shared categories the
# NixOS hosts import; safe to do broadly because dirsAsCategory's per-class
# filtering means a category's darwin aggregate only ever contains modules
# that actually declared a darwin class -- importing `system`, for instance,
# does not drag in bluetooth/networking/kdeconnect/etc, because none of those
# declare flake.modules.darwin. See dirsAsCategory.md.
#
# What actually brings packages and dotfiles across is
# enable-home-manager-darwin.nix (in `system`), which wires
# home-manager.users.elly to the SAME `ellyHomeManager` aggregate the NixOS
# hosts use -- not a lysithea-specific copy. Whatever in that aggregate does
# not evaluate on aarch64-darwin needs excluding at the source, not forked
# here.
{ config, ... }:
{
    flake.modules.darwin.lysitheaConfiguration.imports =
    with config.flake.modules.darwin; [
        # ── this machine ────────────────────────────────────────────────────────
        # nireHost/lysithea/: nixpkgs-hostPlatform, nixpkgs-stateVersion
        lysithea

        # ── shared ───────────────────────────────────────────────────────────────
        nix             # basic-nix-settings: allowUnfree, experimental-features
        system          # enable-home-manager-darwin -- this is what brings
                        # packages and dotfiles in, via ellyHomeManager

        # ── macOS ────────────────────────────────────────────────────────────────
        # homebrew, shell registration, system.primaryUser/nix.enable. Not
        # `desktop-env` or `hardware` or `peripherals` -- none of those declare
        # anything darwin-class, so importing them would resolve to empty
        # aggregates and add nothing. Left out rather than imported-for-nothing.
        macos

        # ── user ─────────────────────────────────────────────────────────────────
        elly            # elly-user (darwin fonts), elly-git (homeManager,
                        # reused via ellyHomeManager already -- listed here too
                        # only because durandal/tenacity list it the same way)
    ];

    flake.modules.darwin.lysitheaConfiguration.networking.hostName = "nire-lysithea";
}
