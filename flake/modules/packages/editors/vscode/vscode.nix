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
# `programs.vscode = { enable = true; package = pkgs.vscode-fhs; }` looks tidier
# and is a trap. The NixOS module has no `mutableExtensionsDir` (that option
# belongs to Home Manager's vscode module) and unconditionally builds
# `programs.vscode.finalPackage` via vscode-with-extensions.override with an
# empty extensions list; with-extensions.nix then wraps the binary with
# `--add-flags "--extensions-dir ${combinedExtensionsDrv}/share/vscode/extensions"`.
# So VS Code launches against an immutable, empty store dir (see above) and
# ~/.vscode/extensions goes invisible. Hit on the first switch of this branch
# on tenacity: "vscode couldn't find extensions folder in nix store".
# environment.systemPackages installs the package without touching the
# extensions directory; the file's other three options are independent and
# stayed. Declarative extensions would be
# `programs.vscode.extensions` with the list actually populated -- and giving
# up GUI installs, since the store directory is then the only one VS Code reads.
#
# 2026-08-11 — ~/.vscode/argv.json is hand-managed, and needs a keyring setting
#
# Not declared here, deliberately -- hit again on any reinstall or first
# durandal run. VS Code shows "An OS keyring couldn't be identified for
# storing the encryption related data in your current desktop environment" and
# cannot save credentials: it guesses the keyring backend and guesses wrong.
# Fix, one key in ~/.vscode/argv.json: `"password-store": "kwallet6"` --
# kwallet6 because `strings lib/vscode/code` offers basic, kwallet5 and
# KWALLET6, and Plasma 6 runs kwalletd6; if it still complains, gnome-libsecret
# is the other candidate (ksecretd runs as a Secret Service bridge on this
# desktop). Version churn, not this config: the old working setup ran
# code-1.109.5, already the FHS/bwrap build, out of the standalone home-manager
# profile; the nixpkgs 26.11 bump moved it to 1.130.0, 21 releases, and
# detection that used to work stopped.
#
# Why not `home.file.".vscode/argv.json"`: that is a read-only store symlink,
# and VS Code writes the file itself -- a generated crash-reporter-id;
# "Configure Runtime Arguments" edits it -- and declaring it meant either
# committing a telemetry UUID or having both hosts share one. Written that way
# once on this branch, reverted (reflog 7b3399f) in favour of leaving it
# mutable.
