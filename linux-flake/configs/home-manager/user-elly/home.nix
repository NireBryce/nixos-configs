{ self, ... }:
{ 
    flake.modules.homeManager."elly" = { import-tree, ... }:
    {
        imports = [
          (import-tree ./configs/home-manager/user-elly)
        ];
    };
}

