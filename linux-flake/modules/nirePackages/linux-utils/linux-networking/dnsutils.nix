{ 
    perSystem = {pkgs, lib, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = {
        # # description = "provides `dig` + `nslookup`";
            home.packages = with pkgs; [
                dnsutils
            ];
        };
    };
}
