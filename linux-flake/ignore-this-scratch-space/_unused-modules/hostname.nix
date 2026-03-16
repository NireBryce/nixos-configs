{
  tenacity.hostname = { host, ... }: {
    ${host.class}.networking.hostName = host.hostName;
  };
}

# https://github.com/vic/vix/blob/den/modules/community/vix/hostname.nix
