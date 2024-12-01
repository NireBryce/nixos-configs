{ 
  pkgs,
  ...
}:

{
  # Darwin packages, for some reason home.packages does not install them, googling found nothing
    home.packages = with pkgs; [
        # discord

    ];
  
    # Managed in darwin config
}
