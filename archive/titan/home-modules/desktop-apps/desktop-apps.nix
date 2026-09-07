{ config, pkgs, ...}:

{
  #desktop-apps
  home.packages = with pkgs; [
    cider
    pkgs.gnome-system-monitor
        shutter

    
  ];
}
