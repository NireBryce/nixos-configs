{ pkgs, ... }: 
{
    # TODO: lib.mkIf lib.mkEnable video
    home.packages = with pkgs; [
      obs-studio
    ];                # obs-studio
}
