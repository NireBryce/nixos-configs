{ pkgs, misc, ... }: {
# Where the ruby packages live
# TODO: lib.mkIf lib.mkEnable 
  home.packages = with pkgs; [
    ruby
  ];
}

