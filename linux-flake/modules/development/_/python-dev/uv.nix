{
    description = "uv - python version-, venv-, and packaging-management tool";
    homeManager =
    { pkgs, ... }:
    {   
        home.packages = with pkgs; [
            uv
        ];
    };
}
