{
    pkgs,
    ...
}:
 
{
    imports = [
        ./broot.nix
    ];
    home.packages = with pkgs;[
        which                         # `which`                                   https://www.gnu.org/software/which/
        file                          # `file` show filetype                      https://darwinsys.com/file
    ];
}
