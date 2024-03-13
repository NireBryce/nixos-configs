# I use `piper` to manage my logitech g600, system settings required for it go here
{ ... }:
{
  # mouse (for piper, which is managed by fleek/home-manager)
  services.ratbagd.enable = true;  
}

