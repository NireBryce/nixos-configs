# desc = "promnesia breadcrumb-bookmarks-and-more";
{ ... }:

{
    home.file.".config/promnesia".source = ./config/config.py;
}
