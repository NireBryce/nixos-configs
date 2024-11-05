# Debug a build that builds only with --impure
impure:
  sudo nixos-rebuild dry-build -vvv --flake "{{FLAKE_PATH}}#{{HOSTNAME}} 2>&1 | tee pure.txt; sudo nixos-rebuild dry-build -vvv --impure --flake {{FLAKE_PATH}}#{{HOSTNAME}} 2>&1 | tee impure.txt; diff -y pure.txt impure.txt"

