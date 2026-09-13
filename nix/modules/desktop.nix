# Plasma 6 on Wayland.
#
# Opt-in per host rather than folded into ./base.nix: both Linux hosts happen
# to want a desktop today, but for opposite reasons - shambhala needs a session
# for Sunshine to capture, myosis has a person in front of it - and a future
# headless host should not inherit a display manager by accident.
#
# Why a host wants a desktop stays with the host: shambhala's autologin and its
# never-blank policy in ./power.nix are not desktop facts, they are facts about
# a machine nobody sits at.
{ pkgs, ... }:

{
  hardware.graphics.enable = true;

  environment.systemPackages = [ pkgs.alacritty ];

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  services.desktopManager.plasma6.enable = true;

  # Steam lives here rather than in a host config because both hosts want it and
  # it is desktop-shaped: the Steam runtime is 32-bit, so it needs
  # hardware.graphics.enable32Bit from the host's GPU module. Enabled without
  # that you get a client that starts and then fails to launch anything.
  programs.steam.enable = true;
}
