# mosh (mobile shell): remote terminal over UDP that survives roaming,
# sleep, and IP changes -- the client half of "get me a shell on another
# machine". Filed under terminals/ by function, next to kitty (the local
# half): mosh is not a terminal emulator, but it exists to put a terminal
# on a remote host, and no shell-apps subcategory is a closer fit.
#
# Client only. Any host accepting inbound mosh additionally needs
# programs.mosh.enable (installs the server and opens UDP 60000-61000);
# nothing here enables that, and no host in this tree does today.
#
# Platform check 2026-09-07: nixpkgs builds it on aarch64-darwin and no
# Homebrew cask collides (`just available mosh`), so no guard needed.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            # mosh: remote shell that keeps the session across roaming and
            # intermittent connectivity
            home.packages = with pkgs; [
                mosh
            ];
        };
}
