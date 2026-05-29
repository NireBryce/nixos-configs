{ 
    perSystem = {pkgs, lib, ...}:
    let
      moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in
    {
        flake.modules.nixos.${moduleName} = {
            environment.systemPackages = with pkgs; [
                cargo
                rustc
                rustup
                rustfmt
                clippy
                rust-analyzer
            ];
        };
    };
}
