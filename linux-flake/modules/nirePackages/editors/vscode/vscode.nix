{ lib, inputs, ... }:
    # TODO: remove need for `inputs`, try `'self?`
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
  flake.modules.nixos.${moduleName} = { pkgs, ... }: {
        # systemPackages, NOT programs.vscode -- see history at the bottom.
        # The NixOS module forces a store path as --extensions-dir, which hides
        # every extension installed through the GUI.
        environment.systemPackages = with pkgs; [
          vscode-fhs
        ];


        programs.nix-ld.enable = true; # Needed for VSCode remote connection, etc
        environment.sessionVariables.NIXOS_OZONE_WL = "1";
        nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ]; # https://discourse.nixos.org/t/vs-code-and-nix-ide-newbie-problems/51385/5
      };
}

# ── history ─────────────────────────────────────────────────────────────────
#
# 2026-08-10 — why this is systemPackages and not `programs.vscode`
#
# It was:
#
#     programs.vscode = { enable = true; package = pkgs.vscode-fhs; };
#
# which looks like the tidier option and is a trap. The NixOS module has no
# `mutableExtensionsDir` -- that option belongs to Home Manager's vscode module,
# not this one -- and it unconditionally builds:
#
#     programs.vscode.finalPackage = pkgs.vscode-with-extensions.override {
#       vscode = cfg.package;
#       vscodeExtensions = cfg.extensions;     # unset here, so [ ]
#     };
#
# and with-extensions.nix wraps the binary with
#
#     --add-flags "--extensions-dir ${combinedExtensionsDrv}/share/vscode/extensions"
#
# So VS Code launches pointed at an immutable, empty store directory, and every
# extension installed through the GUI -- all of ~/.vscode/extensions -- becomes
# invisible. Found the first time this branch was switched on tenacity, as
# "vscode couldn't find extensions folder in nix store".
#
# The module's whole value here was installing the package, which
# environment.systemPackages does without touching the extensions directory.
# The other three options in this file are independent of it and stayed.
#
# If declarative extensions are ever wanted, that is `programs.vscode.extensions`
# with the list actually populated -- and it means giving up GUI installs, since
# the store directory is then the only one VS Code reads.
#
#
# 2026-08-11 — ~/.vscode/argv.json is hand-managed, and needs a keyring setting
#
# NOT declared here, deliberately. Recorded because nothing else in the repo
# says it, and a reinstall or a first run on durandal will hit it again.
#
# VS Code shows "An OS keyring couldn't be identified for storing the
# encryption related data in your current desktop environment" and then cannot
# save credentials, because it guesses the keyring backend and guesses wrong.
# The fix is one key in ~/.vscode/argv.json:
#
#     "password-store": "kwallet6"
#
# kwallet6 because `strings lib/vscode/code` offers basic, kwallet5 and
# KWALLET6, and Plasma 6 runs kwalletd6. If it still complains,
# gnome-libsecret is the other candidate -- ksecretd runs as a Secret Service
# bridge on this desktop.
#
# It is version churn, not anything this config did. The old working setup ran
# code-1.109.5 out of the standalone home-manager profile, already as the
# FHS/bwrap build; the nixpkgs 26.11 bump moved it to 1.130.0, 21 releases, and
# detection that used to work stopped.
#
# Why not `home.file.".vscode/argv.json"`: that makes it a read-only store
# symlink, and VS Code writes to this file itself -- it stores a generated
# crash-reporter-id there, and "Configure Runtime Arguments" edits it. Declaring
# it also meant either committing a telemetry UUID or having both hosts share
# one. It was written that way once, on this branch, and reverted (reflog
# 7b3399f) in favour of leaving the file mutable.
