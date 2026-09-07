# agartha - headless Plasma box: Sunshine/Moonlight host, k3s server, Minecraft
# server. Nothing is ever sat in front of it, which is why autologin is on and
# ../../modules/power.nix forbids sleep.
#
# Rebuild with `nb` (see ../../modules/rebuild.nix).
{ pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nixpkgs.config.allowUnfree = true;

  # Desktop. Autologin is load-bearing, not a convenience: Sunshine captures a
  # running Plasma session, so one has to exist before Moonlight connects.
  hardware.graphics.enable = true;
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  services.displayManager.autoLogin = {
    enable = true;
    user = "turbo";
  };
  services.desktopManager.plasma6.enable = true;

  networking.hostName = "agartha";
  networking.networkmanager.enable = true;
  networking.firewall.allowedUDPPorts = [ 41641 ]; # tailscale
  hardware.enableRedistributableFirmware = true;
  services.tailscale.enable = true;
  services.openssh.enable = true;

  networking.wireguard.enable = true;
  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.100.0.2/24" ];

    # Deployed out of band and root-only. Never put the key itself in this
    # repo: the whole world-readable nix store would get a copy.
    privateKeyFile = "/etc/wireguard/private.key";

    peers = [
      {
        publicKey = "WYcYdP/27F0HEAGYWEqvoHfbnWkROfcQ4nqZ4ecMDQQ=";
        endpoint = "178.156.205.76:51820";
        persistentKeepalive = 25;
        allowedIPs = [ "10.100.0.1/32" ];
      }
    ];
  };

  time.timeZone = "America/New_York";

  programs.steam.enable = true;
  programs.zsh.enable = true; # required: it is turbo's login shell
  security.sudo.wheelNeedsPassword = false;

  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
  };

  # Pins stateful defaults to the release this host was installed from.
  # Do not change it: it is not a "which nixpkgs am I on" knob.
  system.stateVersion = "24.05";
}
