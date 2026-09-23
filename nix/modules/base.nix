{ pkgs, ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nixpkgs.config.allowUnfree = true;

  networking.networkmanager.enable = true;
  hardware.enableRedistributableFirmware = true;

  security.sudo.wheelNeedsPassword = false;

  services.openssh.enable = true;

  services.tailscale.enable = true;
  networking.firewall.allowedUDPPorts = [ 41641 ];

  environment.systemPackages = [ pkgs.claude-code ];
}
