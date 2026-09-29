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
                # curl-to-bash installer; this fetches the same per-platform
                # release zips from https://dl.polytoken.dev/ and pins them,
                # rather than running an unreviewed installer script at
                # activation time.
                #
                # Tracks the "stable" channel, not "latest" -- both are named in
                # https://dl.polytoken.dev/channels.json, which is what the
                # installer resolves. Don't bump by hand: `just pinned-packages
                # bump polytoken` reads channels.json and rewrites `version` and
                # every hash below (skill `pinned-packages`, which also checks
                # whether nixpkgs or llm-agents has started packaging it).
                version = "0.8.16";

                # NAR hash of each unpacked zip, as fetchzip wants. Upstream
                # publishes no checksum the zips can be checked against (see
                # history), so these are trust-on-first-download: computed by
                # fetchzip itself (a fake-hash build's `got:`) when the bump ran.
                platforms = {
                    x86_64-linux   = { urlPlatform = "linux-amd64"; hash = "sha256-O8Oa5aUhl6kC1gMhd0sdMxJHxIFvt+TASUgF6CPtmXE="; };
                    aarch64-linux  = { urlPlatform = "linux-arm64"; hash = "sha256-y0IGLhnn4Yc4xxScXZXHxmskpK+PzpJoexq/NrZNiQA="; };
                    x86_64-darwin  = { urlPlatform = "macos-amd64"; hash = "sha256-dchlIh/tKTshsD+fq/jO1hQpiwdFSSEslEitg1DAqys="; };
                    aarch64-darwin = { urlPlatform = "macos-arm64"; hash = "sha256-zP5mLoXGXQ2lcezSSqyPP1FojlnNNhgpgkxXtUuSsOw="; };
                };

                plat = platforms.${pkgs.stdenv.hostPlatform.system}
                    or (throw "polytoken: no upstream prebuilt release for ${pkgs.stdenv.hostPlatform.system}");

                polytoken = pkgs.stdenv.mkDerivation {
                    pname   = "polytoken";
                    inherit version;

                    src = pkgs.fetchzip {
                        url       = "https://dl.polytoken.dev/${version}/${plat.urlPlatform}/polytoken.zip";
                        stripRoot = false; # the zip holds one bare `polytoken`, no top-level directory
                        inherit (plat) hash;
                    };

                    installPhase = ''
                        runHook preInstall
                        install -Dm755 polytoken $out/bin/polytoken
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

# ── history ─────────────────────────────────────────────────────────────────
#
# 2026-09-01 to 2026-09-28 — fetched the raw binary, checked against SHA256SUMS
#
# Until 2026-09-28 this fetched https://dl.polytoken.dev/<version>/<platform>/polytoken
# (the zip's path minus ".zip") with fetchurl and dontUnpack, pinning the sha256
# published in <version>/SHA256SUMS.linux and .macos; on 2026-09-01 hashing the
# fetched linux-amd64 binary matched its SHA256SUMS.linux entry exactly. By
# 2026-09-28 dl.polytoken.dev returned 404 for both the raw binaries and the
# SHA256SUMS files, for every version tried (0.7.4, 0.8.13, 0.8.15), while the
# docs page and get.polytoken.dev's installer still name them; only the .zip
# answered. The pinned 0.7.4 had no zip left either, so the fetch worked only
# while the binary was still in the local store.
