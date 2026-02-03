# desc = "promnesia breadcrumb-bookmarks-and-more";
{ flake.modules.homeManager.common.knowledgeManagement = 
{ ... }:
{
    home.file.".config/promnesia".source = ./config/config.py;
};

}#
