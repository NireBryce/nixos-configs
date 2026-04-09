{
    description = "yaml jq https://github.com/mikefarah/yq";
    homeManager = { pkgs, ... }: {
        home.packages = with pkgs; [
            yq-go
        ];
    };
}
