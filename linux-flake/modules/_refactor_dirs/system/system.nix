{ nire.system =
{ inputs, ... }:
{ 
    provides = {
        bluetooth = { imports = [ (inputs.import-tree ./_/bluetooth) ]; };
        boot = { imports = [ (inputs.import-tree ./_/boot) ]; };
        firmware = { imports = [ (inputs.import-tree ./_/firmware) ]; };
        flatpak = { imports = [ (inputs.import-tree ./_/flatpak) ]; };
        font = { imports = [ (inputs.import-tree ./_/font) ]; };
        gaming = { imports = [ (inputs.import-tree ./_/gaming) ]; };
        home-manager = { imports = [ (inputs.import-tree ./_/home-manager) ]; };
        kdeconnect = { imports = [ (inputs.import-tree ./_/kdeconnect) ]; };
        networking = { imports = [ (inputs.import-tree ./_/networking) ]; };
        secrets = { imports = [ (inputs.import-tree ./_/secrets) ]; };
        security = { imports = [ (inputs.import-tree ./_/security) ]; };
        sound = { imports = [ (inputs.import-tree ./_/sound) ]; };
        ssh = { imports = [ (inputs.import-tree ./_/ssh) ]; };
        storage = { imports = [ (inputs.import-tree ./_/storage) ]; };
        virtualization = { imports = [ (inputs.import-tree ./_/virtualization) ]; };
        wayland = { imports = [ (inputs.import-tree ./_/wayland) ]; };
        xdg = { imports = [ (inputs.import-tree ./_/xdg) ]; };
    };
    nixos = 
    { pkgs, lib, ... }: 
    {
        programs.nix-ld.enable      = lib.mkDefault true;      # Needed for VSCode remote connection, etc
        services.fwupd.enable       = lib.mkDefault true;      # fwupd
        console = {
            keyMap  = "us";
            font    = "Lat2-Terminus16";
        };
        i18n.defaultLocale  = lib.mkDefault "en_US.UTF-8";
        time.timeZone       = lib.mkDefault "America/New_York"; 
        environment.systemPackages = with pkgs; [
            sbctl # secure boot ctl  
        ];

        boot.loader = {
            # limine.enable               = lib.mkDefault true;
            # limine.secureBoot.enable    = lib.mkDefault true;
            systemd-boot.enable       = lib.mkDefault true;
            efi.canTouchEfiVariables    = lib.mkDefault true;
        };
    };

};
}
