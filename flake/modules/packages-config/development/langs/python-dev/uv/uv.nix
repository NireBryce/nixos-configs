# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: {
        # description = "uv - python version-, venv-, and packaging-management tool";
        home.packages = with pkgs; [
          uv
        ];
    };
}
