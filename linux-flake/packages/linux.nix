{ import-tree, ... }:
{ 
    packages.linux.homeManager = {
        imports = [
            (import-tree ./pkgs-hm)
        ];
    };

    packages.linux.nixos = {
        imports = [
            (import-tree ./pkgs-system)
        ];
    };
}
