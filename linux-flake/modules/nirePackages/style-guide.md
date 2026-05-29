opening brackets should be on the same line as what causes them, to reduce clutter and make it easier to visually debug for me, ie
```nix
{
    let
        x = y;
    in {
        flake.modules.homeManager.myModule = {
            x;
        };
    };
}
```


