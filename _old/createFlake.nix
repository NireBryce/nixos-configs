let 
# Auto-discovers and imports every .nix file under ./modules/
outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);

in

outputs

# https://github.com/vic/vix/blob/d0352c8ba4393fa40eb8e957a30286ef1fac4635/default.nix#L4
