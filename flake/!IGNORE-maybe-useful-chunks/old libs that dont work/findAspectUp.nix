# Walk up until finding the directory that sits directly under
# the namespace directory (i.e. two levels under modules/).
# e.g. modules/nirePackages/editors/scm/git.nix -> "editors"
{ ... }:
let
  findAspectUp = path:
    let parent = dirOf path;
    in if baseNameOf (dirOf parent) == "modules"
       then baseNameOf parent
       else findAspectUp parent;
in {
  inherit findAspectUp;
}
