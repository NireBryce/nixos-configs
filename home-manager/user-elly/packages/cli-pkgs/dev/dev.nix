{ 
    pkgs, 
    ... 
}: 
{
  #todo splitme
    home.packages = with pkgs;[
    # nix dev
      nixfmt
      nil
    # python dev
      uv                            # `pyenv` but it's actually good
      ruff                          # python linter                             https://github.com/astral-sh/ruff
      # ruff-lsp                      # ruff integration with vscode              https://github.com/astral-sh/ruff-lsp
    # bash dev
      shellcheck                    # bash linter                               https://www.shellcheck.net/
      shfmt                         # bash formatter                            https://github.com/mvdan/sh
    # general utils
      diffutils                     # `diff` utils                              https://github.com/ogham/diffutils
      direnv                        # per-directory environments                https://github.com/direnv/direnv
      sqlite                        # sqlite                                    https://www.sqlite.org/
      riffdiff                      # provides `riff`, where-in-line diff       https://github.com/walles/riff
    # git                       # git                                       # git  
      gh                            # github cli                                https://github.com/cli/cli
      git                           # git scm                                   https://git-scm.com
      delta                         # `delta` - git diff                        https://github.com/dandavison/delta
      lazygit                       # TUI git interface                         https://github.com/jesseduffield/lazygit
      commitizen                    # commitizen                                https://github.com/commitizen-tools/commitizen
    # docker
      lazydocker                    # TUI docker interface                      https://github.com/jesseduffield/lazydocker
  
      entr                          # run commands when files change            https://github.com/eradman/entr
      tokei                         # count lines of code                       https://github.com/XAMPPRocky/tokei
      mprocs                        # run multiple commands in parallel         https://github.com/ogham/mprocs
      
  ];
}
