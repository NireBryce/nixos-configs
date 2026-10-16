# Module file: named after this file; why it looks this way: wiki/module-files.md
{ lib, ... }:
{
    nixos = {
        i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
    };
}
