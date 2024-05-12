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

# TODO: do nix automatic garbage collection https://www.youtube.com/watch?v=uS8Bx8nQots 
