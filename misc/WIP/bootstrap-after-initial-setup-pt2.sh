# create the ~/nixos/nire-<hostname> folder and then:
nix-shell -p sops --run "sops <hostame-folder>/secrets.yaml"

