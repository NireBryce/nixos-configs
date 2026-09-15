{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
        # provides `dig` + `nslookup`
            home.packages = with pkgs; [
                dnsutils
            ];
        };
}
