{ lib, ...}:
{
  imports = [
    ./_gpu.amdgpu+.nix
   ];
  _amdgpu.enable = lib.mkDefault true;
}

