{
    pkgs,
    ...
}:
{
    home.packages = with pkgs;[
        aria2                         # cli download manager                      https://aria2.github.io/
        magic-wormhole-rs             # easy transfer arbitrary files encrypted   https://github.com/magic-wormhole/magic-wormhole.rs
        rsync                         # up hill both ways                         https://linux.die.net/man/1/rsync
    ];
}
