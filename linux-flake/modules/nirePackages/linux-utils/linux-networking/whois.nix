{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: lib.mkIf (!pkgs.stdenv.isDarwin) {
            # # description = "whois lookup https://packages.qa.debian.org/w/whois.html";
            home.packages = with pkgs; [
                whois
            ];
        };
}
