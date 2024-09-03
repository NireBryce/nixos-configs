{ 
  pkgs,
  ... 
}:
{
  environment.systemPackages = with pkgs; [
    inshellisense
    starship
    blesh
  ];

  
  
}
