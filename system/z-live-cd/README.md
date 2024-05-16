check me then paste: 

nix-build custom-iso.nix 
sudo dd if=result/iso/nixos-24.05pre-git-x86_64-linux.iso of=/dev/sdd bs=4M conv=fsync

(thanks to https://nixos.mayflower.consulting/blog/2018/09/11/custom-images/)