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
