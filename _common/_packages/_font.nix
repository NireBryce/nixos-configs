{ ... }:

{
  fonts.packages = with pkgs; [
    (nerdfonts.override { 
      fonts = [ 
        "FiraCode" "DroidSansMono" "Iosevka" "JetBrainsMono" "monofur" ]; 
      }
    )
  ];
  console.font = "FiraCode";
 
}
