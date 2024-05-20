{ lib, ... }:
{
  imports = [
    ./.snd.pipewire+.nix
    ./.snd.pipewire-bt+.nix
   ];
  _pipewire.enable = lib.mkDefault true;
  _pipewire-bt.enable = lib.mkDefault true;
}
