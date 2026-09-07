# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, inputs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ];

  home-manager.useGlobalPkgs = true;

  programs.nix-ld.enable = true;

  swapDevices = [{
    device = "/swapfile";
    size = 16*1024;
  }];

    #printing
    services.printing.enable = true;

    services.avahi = {
  enable = true;
  nssmdns4 = true;
  openFirewall = true;
};


programs.virt-manager.enable = true;

users.groups.libvirtd.members = ["turbo"];

virtualisation.libvirtd.enable = true;

virtualisation.spiceUSBRedirection.enable = true;
#
#
# # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
#
  networking.hostName = "turbo"; # Define your hostname.
#
  # Enable networking
  networking.networkmanager.enable = true;
#
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
#
# Set your time zone.
  time.timeZone = "America/New_York";
#
# Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };
#
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.turbo = {
    isNormalUser = true;
    description = "Cameron Dunn";
    extraGroups = [ "networkmanager" "wheel" "libvirtd" "input" ];
    shell = pkgs.bash;
    packages = with pkgs; [
      lunar-client
    ];
  };
#
  fonts.packages = [
    pkgs.nerd-fonts._0xproto
  ];
#
# # Enable automatic login for the user.
  services.getty.autologinUser = "turbo";
#
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
#
#
  environment.systemPackages = with pkgs; [
        lutris
        protonup
    home-manager
        wine
  ];

#
  system.stateVersion = "23.11"; # Did you read the comment?

}
