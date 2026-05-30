{ 
    perSystem = {pkgs, lib, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = {
            # # description = "nixd lsp";
            home.packages = with pkgs; [
                nixd
            ];
        };
  
        flake.modules.nixos.${moduleName} = {
            environment.systemPackages = with pkgs; [
                nixd
            ];
        };
    };
}

