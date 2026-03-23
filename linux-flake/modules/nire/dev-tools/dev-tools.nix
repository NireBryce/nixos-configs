{ self, inputs, ...}:
{ flake.modules.nixos.dev-tools =
{
    # TODO: find a better way to merge this
    imports = [
        self.modules.nixos.dev-tools-rust
        self.modules.nixos.dev-tools-devenv
    ];
}
;}
