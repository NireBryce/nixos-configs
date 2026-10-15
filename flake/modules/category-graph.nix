# This file declares the `flake.categoryGraph` option. The option holds one
# entry per category: its directory, the module files it collects, and the
# categories nested directly inside it.
#
# Each category sets its own entry: its shim runs the collector
# (_lib/category-collector.nix), which builds the entry from the same
# directory walk that builds the category's import lists. So the entry
# always matches what hosts import.
#
# Read it with:
#
#   nix eval --json ./flake#categoryGraph
#
# This has to be a declared option. flake-parts accepts only one definition
# per undeclared `flake` attribute, and each category sets its own key
# here; without the declaration, evaluation fails with "No option has been
# declared for this flake output attribute".
#
# The file sits at the top of modules/, outside every category folder, so
# no category collects it. checks.nix sits there for the same reason.
{ lib, ... }:
{
    options.flake.categoryGraph = lib.mkOption {
        description = "One entry per category, keyed by category name. Each category sets its own entry, from the directory walk that builds its import lists.";
        default = { };
        type = lib.types.lazyAttrsOf (lib.types.submodule {
            options = {
                dir = lib.mkOption {
                    type = lib.types.str;
                    description = "Path of the category's folder, relative to modules/, e.g. \"packages-config/shell-apps\".";
                };
                files = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    description = "Paths of the module files this category collects itself, relative to modules/. A file inside a nested category is listed under that category instead.";
                };
                nested = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    description = "Names of the categories inside this category's folder that are not inside another nested category. Each name is also a key of categoryGraph.";
                };
            };
        });
    };
}
