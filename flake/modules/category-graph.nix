# Declares flake.categoryGraph: what each category collects, as data.
#
# Every dirsAsCategory.nix shim defines its own key in it
# (_lib/category-collector.nix, at the bottom), from the same directory walk
# that builds the category's import lists -- so the published graph cannot
# drift from what hosts actually get. Tools read it instead of re-deriving
# membership by parsing files:
#
#   nix eval --json ./flake#categoryGraph
#
# Declared as an option because flake-parts' freeform `flake` attributes
# accept one definition each; ~40 shims each defining one key would fail as
# "No option has been declared for this flake output attribute".
#
# This file sits at the top of modules/, outside every category, so no
# dirsAsCategory collects it (same as checks.nix).
{ lib, ... }:
{
    options.flake.categoryGraph = lib.mkOption {
        description = "Per category: its directory, the module files it collects itself, and the categories nested directly in it.";
        default = { };
        type = lib.types.lazyAttrsOf (lib.types.submodule {
            options = {
                dir = lib.mkOption {
                    type = lib.types.str;
                    description = "The category's directory, relative to modules/.";
                };
                files = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    description = "Module files the category collects itself, relative to modules/; not those inside a nested category.";
                };
                nested = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    description = "Names of the categories nested directly inside it.";
                };
            };
        });
    };
}
