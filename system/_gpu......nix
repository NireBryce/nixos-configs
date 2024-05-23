{ pkgs, ...}:

# gpu metapackage
{
  imports = [
    ./_gpu.amdgpu+.nix
   ];
   environment.systemPackages = with pkgs; [
      glfw
      dxvk
   ];
}

