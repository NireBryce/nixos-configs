BASE=/Users/elly/nixos/linux-flake/configs/home-manager/user-elly

# Find all den-wrapped .nix files in both dirs
find "$BASE/pkgs-cli" "$BASE/pkgs-gui" -name '*.nix' | sort | while read -r f; do
    if grep -qE '^\{[[:space:]]*den\.' "$f" || grep -qE '^[[:space:]]*\{[[:space:]]*den\.' "$f"; then
        echo "$f"
    fi
done
