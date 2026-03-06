# desc = "yaml jq https://github.com/mikefarah/yq";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        yq-go
    ];
}
