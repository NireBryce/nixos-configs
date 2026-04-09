{
    nixps = { pkgs, ... }: {
        environment.systemPackages = with pkgs; [
            lm_sensors                    # lm_sensors 
        ];
    };
}
