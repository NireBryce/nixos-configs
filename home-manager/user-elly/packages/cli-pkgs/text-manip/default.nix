{
    pkgs,
    ...
}:
 
{
    imports = [
        
    ];
    home.packages = with pkgs;[
        jc                            # jc converts output into JSON or YAML      https://github.com/kellyjonbrazil/jc
        jq                            # jq                                        https://github.com/stedolan/jq
        yq-go                         # yaml jq                                   https://github.com/mikefarah/yq
    ];
}
