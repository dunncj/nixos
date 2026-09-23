{ lib, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;

  boot.loader.systemd-boot.configurationLimit = 3;

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

  tunnel.address = "10.100.0.3/24";

  services.xserver.xkb.layout = "us";

  services.printing.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  programs.solaar = {
    enable = true;
    userService.enable = true;
  };

  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    package = pkgs.sunshine.override { cudaSupport = true; };
    settings = {
      capture = "kms";
      global_prep_cmd = builtins.toJSON [
        {
          do = "${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor --dpms on";
          undo = "";
        }
      ];
    };
  };

  networking.firewall.interfaces.tailscale0 = {
    allowedTCPPorts = [
      47984
      47989
      47990
      48010
    ];
    allowedUDPPorts = [
      47998
      47999
      48000
      48002
      48010
    ];
  };

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";

  programs.firefox.enable = true;

  users.users.turbo.packages = [
    pkgs.kdePackages.kate
    pkgs.lunar-client
    (pkgs.callPackage ./curseforge.nix { })
  ];

  system.stateVersion = "26.05";
}
