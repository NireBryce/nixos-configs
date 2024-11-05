# usage: just nix rebuild home user@hostname <flakepath>
home USER_AT_HOST FLAKE_PATH:
  nh home switch --configuration {{USER_AT_HOST}} {{FLAKE_PATH}}

# usage: nix-rebuild-os hostname <flakepath>
os HOSTNAME FLAKE_PATH:
  nh os switch --hostname {{HOSTNAME}} {{FLAKE_PATH}}
