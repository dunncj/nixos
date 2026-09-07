{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    pulseaudio
    xdg-utils
    pipewire
    seatd
    dconf
    sway
    obs-studio
        cloc
  ];

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

    # hardware.pulseaudio.extraConfig = "ifexists module-bluetooth-policy.so\nload-module module-bluetooth-policy auto_switch=false\n .endif\n.ifexists module-bluetooth-discover.so\nload-module module-bluetooth-discover\nload-module module-switch-on-connect\n                   .endif";


  # hardware.opengl.enable = true;

  xdg = {
    portal = {
      enable = true;
          extraPortals = with pkgs; [
            xdg-desktop-portal-wlr
            xdg-desktop-portal-gtk
          ];
    };
  };

  environment.variables = {
    GSETTINGS_BACKEND="keyfile";
  };

  services.gnome.gnome-keyring.enable = true;
  security.polkit.enable = true;

  services.flatpak.enable = true;
  hardware.bluetooth.enable = true;
    hardware.bluetooth.settings = {
        General = {
            Disable="Headset";
        };
    };
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;


  fonts.packages = [
    pkgs.nerd-fonts._0xproto
  ];
}
