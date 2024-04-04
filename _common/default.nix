{ 
  imports = [
    ./_boot
    ./_filesystem
    ./_networking
    ./_packages
    ./_secrets
    ./_services
    ./_ssh
    ./_users
  ];

  hardware.keyboard.zsa.enable = true;

}
