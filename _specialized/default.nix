{ lib, ... }:
{
  imports = [
    ./_bluetooth
    ./_gui
    ./_gpu
    ./_games
    ./_mouse
    ./_keyboard
    ./_sound
    ./_impermanence
  ];
  # TODO: Documentation
  _amdgpu.enable = lib.mkDefault false;
  _steam.enable = lib.mkDefault false;
  _logitech.enable = lib.mkDefault false;
  _bluetooth.enable = lib.mkDefault false;
  _zsa.enable = lib.mkDefault false;

  _impermanence.enable = lib.mkDefault false;
    _delete-root.enable = lib.mkDefault false;
    _system-partitions.enable = lib.mkDefault false;


  # TODO: headless module that sets these falsefor headless machines
  _sound.enable = lib.mkDefault true;
  _gui.enable = lib.mkDefault true;
  

}
