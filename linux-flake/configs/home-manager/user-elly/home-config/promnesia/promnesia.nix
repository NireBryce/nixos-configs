# desc = "promnesia breadcrumb-bookmarks-and-more";
{ den.bundles.hm.promnesia = 
{ ... }:
{
    home.file.".config/promnesia".source = ./config/config.py;
};

}#
