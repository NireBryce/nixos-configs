{ import-tree, ... }:
{ 
    packages.linux.homeManager = {
        imports = [
            (import-tree ./packages/pkgs-hm)
        ];
    };

    packages.linux.nixos = {
        imports = [
            (import-tree ./packages/pkgs-system)
        ];
    };
}
