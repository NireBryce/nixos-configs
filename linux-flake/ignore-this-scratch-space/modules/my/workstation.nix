# # https://github.com/vic/vix/blob/befe19da4216f45d82ef15cef4fb98dd0181b1bf/modules/my/workstation.nix

# { __findFile, ... }:
# {
#   my.workstation.provides = {
#     # for real-world hw machine
#     hw.includes = [
#       <my.workstation/base>

#       <vix.bootable>
#       <vix.kde-desktop>
#       <vix.kvm-amd>
#       <vix.mexico>
#       <vix.niri-desktop>
#     ];

#     vm.includes = [
#       <my.workstation/base>

#       <vix.installer>
#     ];

#     base.includes = [
#       <vix.dev-laptop>
#       <vix.xfce-desktop>
#     ];
#   };
# }
