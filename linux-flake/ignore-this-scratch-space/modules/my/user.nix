# # https://github.com/vic/vix/blob/befe19da4216f45d82ef15cef4fb98dd0181b1bf/modules/my/user.nix
# # this module configures my user over all my hosts.
# { __findFile, ... }:
# {
#   my.user = <den.lib.parametric> {
#     includes = [
#       <den/primary-user>
#       (<den/user-shell> "fish")

#       <vix/autologin>
#       <vix/nix-index>
#       <vix/nix-registry>
#       <vix/vscode-server>

#       <vic/browser>
#       <vic/cli-tui>
#       <vic/direnv>
#       <vic/doom-btw>
#       <vic/dots>
#       <vic/editors> # for normal people not btw'ing.
#       <vic/fish>
#       <vic/fonts>
#       <vic/git>
#       <vic/hm-backup>
#       <vic/jujutsu>
#       <vic/nix-btw>
#       <vic/secrets>
#       <vic/terminals>
#       <vic/vim-btw>
#     ];
#   };
# }
