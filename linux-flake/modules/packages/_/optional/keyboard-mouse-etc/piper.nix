{
    description = "piper - logitech/razer graphical mouse manager https://github.com/soxoj/piper";
    # note: optional pkg

    homeManager =
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            piper
        ];
    };
}
