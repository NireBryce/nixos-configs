# Wires up `nix fmt`, which previously did nothing (no formatter output).
#
# NOTE: this is deliberately configured but not yet applied. Running it will
# reformat every .nix file in the tree and flatten the aligned-`=` style used
# throughout modules/. Run `nix fmt` as its own commit when you want that.
{ inputs, ... }:
{
    imports = [ inputs.treefmt-nix.flakeModule ];

    perSystem = {
        treefmt = {
            projectRootFile = "flake.nix";
            programs.nixfmt.enable = true;
            # Off until the tree is actually formatted, so `nix flake check`
            # stays green. Flip to true in the same commit as the reformat.
            flakeCheck = false;
        };
    };
}
