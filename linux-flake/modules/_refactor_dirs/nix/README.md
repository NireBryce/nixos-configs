I'm stopping here for now, but the general style guide is shaping up to be:

namespace: nire

each folder in modules/ has it's own aspect, nire.thing

within that it can provide related things through provides

I use import-tree's functionality of ignoring folders that start with an underscore to wrap my modules such that I can represent the directory structure in these top level files, for example here, `modules/nix/nix.nix` which also has `modules/nix/_/nix-settings` and `modules/nix/_/nix-settings`. 

```nix
# modules/nix/nix.nix
{
    nire.nix = {
        # representation of the subfolders as provides
        provides = {
            nix-settings = { imports = [ (import-tree ./_/nix-settings) ]; };
            nix-utils = { imports = [ (import-tree ./_/nix-settings) ]; };
        };
    };
}
```

```nix
# modules/nix/_/nix-settings/<whatever>.nix
{
    nixos = { # this is a nixos module
        # module contents
    };
    homeManager = { # homeManager module
    };
    darwin = { };
}
```

