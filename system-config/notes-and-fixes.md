## **Fixes**

### `SteamTinkerLaunch` requires some workarounds

see: [this gist](https://gist.github.com/jakehamilton/632edeb9d170a2aedc9984a0363523d3)

### I think this is deprecated by it being in the flake

  `programs.command-not-found.enable = lib.mkForce false; # conflicts with nix-index-database`

## Notes

Determine where a build is failing if --impure works.
This is a hack and there must be a better way

```sh
sudo nixos-rebuild dry-build -vvv          --flake .#nire-durandal 2>&1 | tee pure.txt; 
sudo nixos-rebuild dry-build -vvv --impure --flake .#nire-durandal 2>&1 | tee impure.txt; 
diff -y pure.txt impure.txt
```

### ways of overriding kernel

```nix
boot.kernelPackages = pkgs.linuxPackages_6_9;
boot.kernelPackages = pkgs.linux_6_6.override { argsOverride = { version = "6.6.23"; }; };
boot.kernelPackages = lib.mkForce pkgs.linuxPackagesFor (pkgs.linux_6_6.override {argsOverride = {version = "6.6.27";};});
boot.kernelPackages = lib.mkForce pkgs.linuxKernel.kernels.linux_6_6;
boot.kernelPackages = pkgs.linuxPackagesFor (pkgs.linux_6_6.override {
    argsOverride = rec {
    src = pkgs.fetchurl {
        url = "mirror://kernel/linux/kernel/v6.x/linux-${version}.tar.xz";
        sha256 = "IA/RGcue8GvO3NtSvgC6RDFj6rFUKVxYMf7ZoSIRqLk=";
    };
    version = "6.6.23";
    modDirVersion = "6.6.23";
    };
});
```

### musnix

```nix
   musnix.kernel.packages =  pkgs.linuxPackagesFor (pkgs.linux_6_6.override {
     argsOverride = rec {
       src = pkgs.fetchurl {
         url = "mirror://kernel/linux/kernel/v6.x/linux-${version}.tar.xz";
         sha256 = "IA/RGcue8GvO3NtSvgC6RDFj6rFUKVxYMf7ZoSIRqLk=";
       };
       version = "6.6.23";
       modDirVersion = "6.6.23";
     };
   });
```

home manager broke, so I had to use `nix-shell -p home-manager` to bootstrap

nh os switch --hostname nire-durandal ~/nixos

nh home switch --configuration elly@nire-durandal ~/nixos/

## This determines what to add to /run/current-system/sw, generally defined elsewhere

```nix
    environment.pathsToLink = [
        x
        y
        z
    ];
```
