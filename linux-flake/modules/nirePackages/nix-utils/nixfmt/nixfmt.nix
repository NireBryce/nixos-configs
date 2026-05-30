{ 
    perSystem = {pkgs, lib, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = {
            # # description = "nixfmt - .nix file formatter";
            home.packages = with pkgs; [
                nixfmt
            ];
        };
        flake.modules.nixos.${moduleName} = {
            environment.systemPackages = with pkgs; [
                nixfmt
            ];
        };
    };
}
