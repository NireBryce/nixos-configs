{lib, config}:
{
  options = {
    _zsa.enable = lib.mkEnableOption "Enables ZSA keyboard support";
  };
  config = lib.mkIf config._zsa.enable {
    hardware.keyboard.zsa.enable = true;
  };
}
