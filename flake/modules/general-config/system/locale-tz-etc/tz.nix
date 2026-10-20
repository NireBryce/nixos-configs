# dirs-as-categories: the module is named after this file; its categories are the folders above it
{ lib, ... }:
{
    nixos = {
        time.timeZone = lib.mkDefault "America/New_York";
    };
}
