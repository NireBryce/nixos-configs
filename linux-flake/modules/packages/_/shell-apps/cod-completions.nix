{ 
    nixos = 
    { pkgs, ...}:
    {
        environment.systemPackages = with pkgs; [
            cod # Completion daemon
        ];
    };
}
