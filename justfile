# rebuild home-manager

default:
  @just --list

# usage: nix-rebuild-home user@hostname <flakepath>
nix-rebuild-home USER_AT_HOST FLAKE_PATH:
  nh home switch --configuration {{USER_AT_HOST}} {{FLAKE_PATH}}

# usage: nix-rebuild-os hostname <flakepath>
nix-rebuild-os HOSTNAME FLAKE_PATH:
   nh os switch --hostname {{HOSTNAME}} {{FLAKE_PATH}}

# find what makes your build impure, the brute force way.  It will create pure.txt and impure.txt
nix-debug-impure HOSTNAME FLAKE_PATH:
  sudo nixos-rebuild dry-build -vvv --flake "{{FLAKE_PATH}}#{{HOSTNAME}} 2>&1 | tee pure.txt; sudo nixos-rebuild dry-build -vvv --impure --flake {{FLAKE_PATH}}#{{HOSTNAME}} 2>&1 | tee impure.txt; diff -y pure.txt impure.txt"

# find event name with `sudo libinput list-devices`
kde-fix-middle-mouse-scroll EVENT_NAME:
  qdbus org.kde.KWin /org/kde/KWin/InputDevice/{{EVENT_NAME}} org.kde.KWin.InputDevice.scrollOnButtonDown true
