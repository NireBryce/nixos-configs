# Needed for first run	
  abbr -g "--help"="--help | bat --language man";
  abbr -g "pamac-refresh-mirrors"="pacman-mirrors -f 5 && sudo pacman -Syuu";
  abbr -g "_regex-extract_url"="'(https?|ftp|file)://[^\s/\$.?#].[^\s]*'";

# TODO: reduce dependence on zsh plugins, either move to fish or figure out a better abbr manager
