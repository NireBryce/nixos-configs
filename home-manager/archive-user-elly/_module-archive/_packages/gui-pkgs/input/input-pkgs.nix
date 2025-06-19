{ 
    pkgs, 
    ... 
}: 
{
    home.packages = with pkgs;[ 
      # keyboard
        qmk                           # qmk keyboard manager                      https://github.com/qmk/qmk_firmware
    # mouse
        piper                         # logitech/razer mouse manager              https://github.com/soxoj/piper
    ];
}
