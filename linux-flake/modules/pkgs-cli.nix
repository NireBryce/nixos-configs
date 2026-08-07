# Package group aggregates. Each file under modules/pkgs/<group>/ opts itself
# into its group, exactly as the nixos modules opt into base/desktop/handheld;
# these three lines are all that attaches the groups to elly.
#
# The groups are kept separate rather than everything opting straight into
# ellyHomeManager so a host role can take some and not others later, without
# touching the individual package files.
{ config, ... }:
{
    flake.modules.homeManager.ellyHomeManager.imports = [ config.flake.modules.homeManager.pkgs-cli ];
}
