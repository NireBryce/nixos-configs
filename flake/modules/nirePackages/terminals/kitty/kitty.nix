# kitty, installation only. The configuration is kitty-config.nix, alongside
# this file.
#
# Split 2026-08-12 so that the darwin question below never has to touch the
# keybindings. nire/macos/homebrew/homebrew.nix installs the `kitty` cask, so
# lysithea had two copies -- and the obvious fix, wrapping the whole module in
# lib.mkIf (!pkgs.stdenv.isDarwin), would have thrown the config away with the
# package. Keeping the two concerns in separate files makes that mistake
# harder to make.
#
# Both files write into `programs.kitty`, which is an attrset merge and fine.
# They must NOT both declare a home.file.<n>.text: that option is types.lines
# and concatenates silently rather than conflicting. bash.nix and blesh.nix,
# the other split pair in this tree, did exactly that to .blerc.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, lib, ... }: {
            # kitty terminal emulator
            home.packages = with pkgs; [
                kitty-img
            ];

            programs.kitty.enable  = true;

            # null, not a disabled module: Home Manager guards its whole config
            # block with `mkIf cfg.enable`, so disabling kitty here would take
            # kitty-config.nix's kitty.conf with it. package = null is a
            # nullable mkPackageOption, and `home.packages` is built with
            # `optional (cfg.package != null)`, so this drops the binary and
            # generates the config regardless -- which is what darwin wants,
            # since the Homebrew kitty reads the same ~/.config/kitty.
            programs.kitty.package = lib.mkIf pkgs.stdenv.isDarwin null;
        };
}
