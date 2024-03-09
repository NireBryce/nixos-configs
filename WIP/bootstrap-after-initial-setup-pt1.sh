#! /bin/bash
# sops

echo "generate sops key\n"
nix-shell -p ssh-to-age --run 'cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age'
echo "\nadd above output to .sops.yaml\n"

echo "\nprivate key\n"
nix-shell -p ssh-to-age --run "sudo ssh-to-age -private-key -i /etc/ssh/ssh_host_ed25519_key | install -D -m 400 /dev/stdin ~/.config/sops/age/keys.txt"

