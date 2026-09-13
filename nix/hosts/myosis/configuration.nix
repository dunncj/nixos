# myosis - Cameron's workstation. Intel i7-13700K, NVIDIA RTX 50-series
# (Blackwell), one Acer XB273K V6 on HDMI, dual-booting Windows off the same
# disk.
#
# Deliberately not shambhala's twin. That host is headless and never sat at,
# which is what justifies its autologin, its never-sleep policy and its
# synthetic-EDID Sunshine hack. Someone is sat at this one, so it takes the
# desktop and the turbo environment and none of the server modules - see
# ../../flake.nix for the module list and why.
#
# Rebuild with `nb` (see ../../modules/rebuild.nix).
{ pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # The ESP here is the 200 MB one Windows created, not a roomy NixOS-sized
  # one, and it is already ~45% full. An NVIDIA initrd is not small, so the
  # default of keeping every generation would fill it and then fail a rebuild
  # partway through installing the bootloader, which is a bad moment to run out
  # of disk. Three leaves room to roll back twice.
  boot.loader.systemd-boot.configurationLimit = 3;

  networking.hostName = "myosis";

  # Peer address on the wg0 tunnel; the rest is in ../../modules/wireguard.nix.
  # Deliberately .3 - shambhala holds .2, and two peers on one address fails
  # like packet loss rather than like a config error. The matching private key
  # is NOT in this repo; generate it and place it at /etc/wireguard/private.key,
  # then add this host's public key to the VPS.
  tunnel.address = "10.100.0.3/24";

  # No autologin, unlike shambhala: there is a person here, so the login prompt
  # is doing real work.
  services.xserver.xkb.layout = "us";

  services.printing.enable = true;

  # Intel controller at USB 8087:0032, the other half of the AX210 that
  # provides wlp110s0. The kernel already binds it - hci0 exists without this -
  # but nothing drives it until bluez is enabled, which is the whole reason
  # Bluetooth appeared dead. Its firmware comes from
  # hardware.enableRedistributableFirmware in ../../modules/base.nix.
  #
  # No blueman: Plasma ships bluedevil, and two applets fighting over the same
  # adapter is worse than one.
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # From this machine's own install, not copied from shambhala, which is on
  # America/New_York.
  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";

  programs.firefox.enable = true;

  # Merges with the turbo environment that ../../turbo/system.nix installs into
  # this same list.
  users.users.turbo.packages = [ pkgs.kdePackages.kate ];

  # Pins stateful defaults to the release this host was installed from (26.05).
  # Do not change it: it is not a "which nixpkgs am I on" knob. Deliberately not
  # shambhala's 24.05 - that is its install date, not this machine's.
  system.stateVersion = "26.05";
}
