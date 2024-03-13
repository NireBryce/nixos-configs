{ pkgs, ... }:

{
  fonts.packages = with pkgs; [
    (nerdfonts.override { 
      fonts = [ 
        "FiraCode" "DroidSansMono" "Iosevka" "JetBrainsMono" ]; 
      }
    )
  ];
  console.font = "FiraCode";
 
}
