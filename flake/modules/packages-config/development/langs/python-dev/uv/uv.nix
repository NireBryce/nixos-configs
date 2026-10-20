# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: {
        # description = "uv - python version-, venv-, and packaging-management tool";
        home.packages = with pkgs; [
          uv
        ];
    };
}
