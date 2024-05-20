{ lib, ...}:
{
  imports = [
    ./.gpu.amdgpu+.nix
   ];
  _amdgpu.enable = lib.mkDefault true;
}

