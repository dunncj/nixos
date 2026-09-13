# shambhala - headless Plasma box: Sunshine/Moonlight host, k3s server, Minecraft
# server. Nothing is ever sat in front of it, which is why autologin is on and
# ../../modules/power.nix forbids sleep.
#
# Boot loader, kernel, flakes, allowUnfree, NetworkManager and firmware now come
# from ../../modules/base.nix; the display manager and Plasma from
# ../../modules/desktop.nix. Both are listed for this host in ../../flake.nix.
# What is left here is only what is true of shambhala specifically.
#
# Rebuild with `nb` (see ../../modules/rebuild.nix).
{ ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # Autologin is load-bearing, not a convenience: Sunshine captures a running
  # Plasma session, so one has to exist before Moonlight connects.
  services.displayManager.autoLogin = {
    enable = true;
    user = "turbo";
  };

  networking.hostName = "shambhala";

  # Peer address on the wg0 tunnel; the rest is in ../../modules/wireguard.nix.
  tunnel.address = "10.100.0.2/24";

  time.timeZone = "America/New_York";

  # Pins stateful defaults to the release this host was installed from.
  # Do not change it: it is not a "which nixpkgs am I on" knob.
  system.stateVersion = "24.05";
}
