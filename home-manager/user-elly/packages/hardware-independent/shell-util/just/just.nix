
  {
      pkgs,
      ...
  }:
   
  {
      home.packages = with pkgs;[
                just                          # just                                      https://github.com/casey/just
      ];
  }
