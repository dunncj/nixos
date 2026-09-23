{ pkgs, ... }:

{
  hardware.graphics.enable = true;

  environment.systemPackages = [ pkgs.alacritty ];

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  services.desktopManager.plasma6.enable = true;

  programs.steam.enable = true;
}
