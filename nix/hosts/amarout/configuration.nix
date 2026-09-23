{ pkgs, ... }:
{
  nixpkgs.hostPlatform = "aarch64-darwin";

  system.primaryUser = "turbo";

  networking.computerName = "amarout";
  networking.hostName = "amarout";
  networking.localHostName = "amarout";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  documentation.enable = false;

  system.stateVersion = 6;

  environment.systemPackages = [ pkgs.rustup ];
}
