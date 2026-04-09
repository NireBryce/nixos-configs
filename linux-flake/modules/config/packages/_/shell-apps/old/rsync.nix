{ 
    description = "rsync - back in my day we transfered our files uphill both ways";

    homeManager = { pkgs, ... }: {
        home.packages = with pkgs; [
            rsync
        ];
    };
}
