# myosis - Cameron's workstation. Intel i7-13700K, NVIDIA RTX 50-series
# (Blackwell), one Acer XB273K V6 on HDMI, dual-booting Windows off the same
# disk.
#
# Deliberately not shambhala's twin. That host is headless and never sat at,
# which is what justifies its autologin, its never-lock policy and its
# synthetic-EDID Sunshine hack. Someone is sat at this one, so it takes the
# desktop and the turbo environment and none of the server modules - see
# ../../flake.nix for the module list and why. It does share one thing: it
# never sleeps (below).
#
# Rebuild with `nb` (see ../../modules/rebuild.nix).
{ lib, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # LTS kernel rather than base.nix's linuxPackages_latest: the out-of-tree
  # NVIDIA module lags new kernels, and 7.2 + driver 595 froze the desktop
  # (see ../../modules/nvidia.nix). 6.18 + 580 is the known-good pair.
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;

  # The ESP here is the 200 MB one Windows created, not a roomy NixOS-sized
  # one, and it is already ~45% full. An NVIDIA initrd is not small, so the
  # default of keeping every generation would fill it and then fail a rebuild
  # partway through installing the bootloader, which is a bad moment to run out
  # of disk. Three leaves room to roll back twice.
  boot.loader.systemd-boot.configurationLimit = 3;

  # Never sleep: a suspended box drops off the mesh until someone wakes it.
  # This is only the sleep half of ../../modules/power.nix. Its no-lock and
  # no-blank settings exist for Sunshine on a headless server, and someone
  # sits at this machine, so the screen still locks and blanks as usual.
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };
  services.logind.settings.Login = {
    IdleAction = "ignore";
    HandleSuspendKey = "ignore";
    HandleHibernateKey = "ignore";
  };

  networking.hostName = "myosis";

  # Peer address on the wg0 tunnel; the rest is in ../../modules/wireguard.nix.
  # Deliberately .3 - shambhala holds .2, and two peers on one address fails
  # like packet loss rather than like a config error.
  #
  # The matching private key is NOT in this repo and has not been generated
  # yet, so tunnel.privateKeySecret is left null and this host falls back to
  # /etc/wireguard/private.key. To finish it: generate the key, add its public
  # half to the VPS, then put the private half in ../../secrets/secrets.yaml as
  # its own entry -- NOT wireguard/private_key, which is shambhala's. Two peers
  # sharing one key share a public key and the VPS cannot tell them apart.
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

  # Logitech PRO X 2 on a Lightspeed receiver (046d:c54d). Its DPI is set on
  # the mouse with Solaar rather than slowed down in KDE, which would throw away
  # sensor precision. Not libratbag/piper: this kernel does not know c54d, so
  # hid-logitech-dj never binds it and ratbagd sees no devices. Solaar speaks
  # HID++ over hidraw directly, and this installs the udev rules that let it do
  # so without root. Without them every /dev/hidraw* is root-only and Solaar
  # reports "No supported device found", which looks exactly like the mouse
  # having forgotten its DPI.
  #
  # Solaar cannot edit this mouse's onboard profiles, so the mouse runs with
  # them disabled and the DPI lives in ~/.config/solaar/config.yaml instead.
  # The mouse forgets it on power-off and Solaar only writes it back while it
  # is running, so what keeps the DPI is Solaar staying up: userService, not an
  # /etc/xdg/autostart entry, which gets one attempt at login and stays dead
  # until the next one if it loses the race with the session.
  #
  # programs.solaar, not hardware.logitech.wireless.enableGraphical: that name
  # is a deprecated alias for this one, and going through it silently skips the
  # service.
  programs.solaar = {
    enable = true;
    userService.enable = true;
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
