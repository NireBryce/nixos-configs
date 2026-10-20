# dirs-as-categories: the module is named after this file; its categories are the folders above it
{ lib, ... }:
{
    nixos = {
        i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
    };
}
