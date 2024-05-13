{ lib, ... }:
{
  imports = [
    ./_bluetooth
    ./_gui
    ./_gpu
    ./_mouse
    ./_keyboard
    ./_sound
    ./_impermanence
  ];
  _amdgpu.enable = lib.mkDefault false;
  _logitech.enable = lib.mkDefault false;
  _bluetooth.enable = lib.mkDefault false;
  _zsa.enable = lib.mkDefault false;
  _impermanence.enable = lib.mkDefault false;


  # TODO: headless module that sets these falsefor headless machines
  _sound.enable = lib.mkDefault true;
  _gui.enable = lib.mkDefault true;
  

}
