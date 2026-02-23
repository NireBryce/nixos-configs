# desc = "promnesia breadcrumb-bookmarks-and-more";
{ den.aspects.pkgs-cli.homeManager = 
{ ... }:
{
    home.file.".config/promnesia".source = ./config/config.py;
};

}#
