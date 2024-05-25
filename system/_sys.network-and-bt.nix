{ ... }:

# networking metapackage
{
# wifi
  networking.networkmanager.enable = true;  # Needs to be 'true' for KDE networking

# Bluetooth
  hardware.bluetooth.powerOnBoot = true;
  hardware.bluetooth.enable =  true;
  hardware.bluetooth.settings = {
    General = {
      FastConnectable = true;
      DiscoverableTimeout =  60;  # seconds
      PairableTimeout = 60;       # seconds
    };
  };
}

# services.blueman.enable = true;
