# rebuild home-manager

_default:
  @just --list


[group('zsh')]
zsh-keymap: 
  bindkey

[group('zsh')]
zsh-highlighting-theme-default:
  fast-theme sv-orple




# find event name with `sudo libinput list-devices`
[group('fix')]
fix-kde-middle-mouse-scroll EVENT_NAME:
  "qdbus org.kde.KWin"                          /
  + " "                                         /
  + "/org/kde/KWin/InputDevice/{{EVENT_NAME}}"  / 
  + " "                                         / 
  + "org.kde.KWin.InputDevice.scrollOnButtonDown true"

[group('nix')]
FLAKE_PATH := "~/nixos"

# update the flake in the default repo
[group('nix-flake-update')]
nix-flake-update:
  nix flake update {{FLAKE_PATH}} && git commit -m "chore: update flake inputs"

# Debug a build that builds only with --impure
[group('nix-debug')]
nix-debug-impure HOSTNAME:
  rebuild-pure := "sudo "                       /              
  + "nixos-rebuild dry-build "                  /
  + " -vvv "                                    /
  + "--flake "                                  /
  + "{{FLAKE_PATH}}#{{HOSTNAME}} "              / 
  + "2>&1 | tee /tmp/nixos-debug-pure.txt "

  rebuild-impure := "sudo "                     / 
  + "nixos-rebuild dry-build "                  /
  + "-vvv "                                     /
  + "--flake "                                  /
  + "{{FLAKE_PATH}}#{{HOSTNAME}} "              /
  + "2>&1 | tee /tmp/nixos-debug-impure.txt"
  
  rebuild-pure
  rebuild-impure
  
  "diff -y "                    /
  + "/tmp/nixos-debug-pure.txt" /
  + " "                         /
  + "/tmp/nixos-debug-impure.txt"

# usage: just nix rebuild home user@hostname <flakepath>
[group('nix-rebuild')]
nix-rebuild-home USER_AT_HOST:
  "nh home switch "                     /
  + "--configuration "                  /
  + "{{USER_AT_HOST}} "                 /
  + "{{FLAKE_PATH}}"

# usage: nix-rebuild-os hostname <flakepath>
[group('nix-rebuild')]
nix-rebuild-system HOSTNAME:
  ""                                    /
  + "nh os switch "                     /
  + "--hostname "                       / 
  + "{{HOSTNAME}} "                     / 
  + "{{FLAKE_PATH}}"
  

# # usage: nix-rebuild-home user@hostname <flakepath>
# nix-rebuild-home USER_AT_HOST FLAKE_PATH:
#   nh home switch --configuration {{USER_AT_HOST}} {{FLAKE_PATH}}

# # usage: nix-rebuild-os hostname <flakepath>
# nix-rebuild-os HOSTNAME FLAKE_PATH:
#   nh os switch --hostname {{HOSTNAME}} {{FLAKE_PATH}}

# find what makes your build impure, the brute force way.  It will create pure.txt and impure.txt
# nix-debug-impure HOSTNAME FLAKE_PATH:
#   rebuild-pure   := ( "sudo" 
#                       + "nixos-rebuild dry-build -vvv --flake"
#                       + {{FLAKE_PATH}}
#                       + "#"
#                       + {{HOSTNAME}}
#                       + " 2>&1 | tee /tmp/nixos-debug-pure.txt" 
#   )
#   rebuild-impure  := ( "sudo"
#                       + "nixos-rebuild dry-build -vvv --impure --flake"
#                       + {{FLAKE_PATH}}
#                       + "#"
#                       + {{HOSTNAME}}
#                       + " 2>&1 | tee /tmp/nixos-debug-impure.txt"
#   )
#   rebuild-impure
#   rebuild-pure
#   diff -y /tmp/nixos-debug-pure.txt /tmp/nixos-debug-impure.txt
  
# # find event name with `sudo libinput list-devices`
# kde-fix-middle-mouse-scroll EVENT_NAME:
#   qdbus org.kde.KWin /org/kde/KWin/InputDevice/{{EVENT_NAME}} org.kde.KWin.InputDevice.scrollOnButtonDown true



# https://just.systems/man/en/selecting-recipes-to-run-with-an-interactive-chooser.html 
# need to fix zsh fzf integrations to use this
