{ pkgs, ...}:

# gpu metapackage
{
  imports = [
    ./.gpu.amdgpu+.nix
   ];
   environment.systemPackages = with pkgs; [
      glfw
      dxvk
   ];
}

