{ lib, ... }:
{
  imports = [
    ./_snd.pipewire+.nix
    ./_snd.pipewire-bt+.nix
   ];
  _pipewire.enable = lib.mkDefault true;
  _pipewire-bt.enable = lib.mkDefault true;
}
