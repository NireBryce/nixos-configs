{ ... }:

{
    programs.vicinae = {
        enable = true;
        settings = {
            
        };
        systemd = {
            enable = true;
            autoStart = true;
        };

    };
}
