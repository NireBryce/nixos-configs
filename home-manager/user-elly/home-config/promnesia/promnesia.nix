{ ... }:
{
    description = "promnesia breadcrumb-bookmarks-and-more";
    flake.modules.homeManager.base =
    { ... }:
    
    {
        home.file.".config/promnesia".source = ./config/config.py;
    };
}
