{
  configs,
  pkgs,
  ...
}:
{ 
  imports = [
    ./_amdgpu.nix
  ];
}
