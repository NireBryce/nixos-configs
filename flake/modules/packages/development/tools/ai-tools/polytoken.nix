{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }:
            let
                # # description = "polytoken: local-first AI coding agent daemon (CLI/TUI)"
                #
                # Not in nixpkgs (`just available polytoken` -> missing, checked
                # 2026-09-01) and no Homebrew formula/cask either (`brew search
                # polytoken` finds nothing). Upstream's own docs lead with a
                # curl-to-bash installer, but https://dl.polytoken.dev/ also
                # serves the same per-platform static binaries the installer
                # would fetch, each with a published sha256
                # (https://dl.polytoken.dev/<version>/SHA256SUMS.linux and
                # .macos), so this fetches and pins those directly rather than
                # running an unreviewed installer script at activation time.
                #
                # Pinned to the "stable" channel release (0.7.4 as of
                # 2026-09-01), not the floating "latest" channel (0.8.2) --
                # matches this repo's general preference for reproducible pins
                # over tracking a moving tag. Bump by hand: check
                # https://docs.polytoken.dev/installation/downloads/ for the
                # current stable version, then refetch SHA256SUMS.{linux,macos}
                # for that version and update the table below.
                version = "0.7.4";

                # sha256 of the raw per-platform binary (not the .zip -- the
                # unzipped binary is served directly at the same path minus
                # ".zip", confirmed 2026-09-01: fetching it and hashing matched
                # SHA256SUMS.linux's linux-amd64/polytoken entry exactly, so
                # there's no zip/unzip step needed here).
                platforms = {
                    x86_64-linux  = { urlPlatform = "linux-amd64";  sha256 = "ac3948ebaf34ef9f6f8041f9b1217632f87852ad230b40b337e3aa215e9a6bb5"; };
                    aarch64-linux = { urlPlatform = "linux-arm64";  sha256 = "3b35ce3c2603e1d12a91317c2f28350b691b3090ff843becd55024cac61942f7"; };
                    x86_64-darwin = { urlPlatform = "macos-amd64";  sha256 = "2107ea89bbc72b4ca6a392eb616aa8153d2f52cebb643d4728882e4fabaadbc3"; };
                    aarch64-darwin = { urlPlatform = "macos-arm64"; sha256 = "b640a2e50b5c9060d7211d0dfe15a0a53e47845944b87ef10d24bdfce1667ea0"; };
                };

                plat = platforms.${pkgs.stdenv.hostPlatform.system}
                    or (throw "polytoken: no upstream prebuilt release for ${pkgs.stdenv.hostPlatform.system}");

                polytoken = pkgs.stdenv.mkDerivation {
                    pname   = "polytoken";
                    inherit version;

                    src = pkgs.fetchurl {
                        url = "https://dl.polytoken.dev/${version}/${plat.urlPlatform}/polytoken";
                        inherit (plat) sha256;
                    };

                    dontUnpack = true;

                    installPhase = ''
                        runHook preInstall
                        install -Dm755 $src $out/bin/polytoken
                        runHook postInstall
                    '';

                    meta = {
                        description = "Local-first AI coding agent daemon, CLI + TUI";
                        homepage    = "https://docs.polytoken.dev/";
                        mainProgram = "polytoken";
                        platforms   = builtins.attrNames platforms;
                    };
                };
            in {
                home.packages = [
                    polytoken
                ];
            };
    }
