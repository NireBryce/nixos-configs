{
    description = "piper - logitech/razer graphical mouse manager https://github.com/soxoj/piper";

    homeManager = { pkgs, ... }: {
        home.packages = with pkgs; [
            piper
        ];
    };
}
