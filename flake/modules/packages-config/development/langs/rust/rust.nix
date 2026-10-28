# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    nixos = { pkgs, ... }: {
        # package summary: rust -- Rust toolchain (rustc, cargo, rustup, clippy, LSP)
        environment.systemPackages = with pkgs; [
            cargo
            rustc
            rustup
            rustfmt
            clippy
            rust-analyzer
        ];
    };
}
