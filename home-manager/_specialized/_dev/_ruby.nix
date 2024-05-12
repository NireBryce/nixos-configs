{ pkgs, misc, ... }: {
# Where the ruby packages live
  home.packages = with pkgs; [
    ruby
  ];
}

