# desc = "promnesia breadcrumb-bookmarks-and-more";
{ den.aspects.hm.provides.pkgs-cli = 
{ ... }:
{
    home.file.".config/promnesia".source = ./config/config.py;
};

}#
