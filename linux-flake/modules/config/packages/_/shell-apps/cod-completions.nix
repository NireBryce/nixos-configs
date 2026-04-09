{ 
    description = "Cod - Completion daemon";
    nixos = { pkgs, ...}: {
        environment.systemPackages = with pkgs; [
            cod 
        ];
    };
}
