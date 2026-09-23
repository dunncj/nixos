{ ... }:

{
  imports = [ ./hardware-configuration.nix ];

  services.displayManager.autoLogin = {
    enable = true;
    user = "turbo";
  };

  networking.hostName = "shambhala";

  tunnel.address = "10.100.0.2/24";

  tunnel.privateKeySecret = "wireguard/private_key";

  time.timeZone = "America/New_York";

  system.stateVersion = "24.05";
}
