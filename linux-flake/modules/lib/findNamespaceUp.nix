# Walk up the directory tree until finding the directory that sits
# directly under a directory named "modules/". Returns that directory's
# name, which corresponds to the den namespace (e.g. "nirePackages").
#
# Usage: findNamespaceUp (builtins.dirOf __curPos.file)
{ ... }: 
let
  findNamespaceUp = path:
    let parent = dirOf path;
    in if baseNameOf parent == "modules"
       then baseNameOf path
       else findNamespaceUp parent;
in {
  inherit findNamespaceUp;
}
