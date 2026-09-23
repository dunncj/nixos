{ config, ... }:

{
  services.xserver.videoDrivers = [ "nvidia" ];

  boot.kernelParams = [ "nvidia.NVreg_OpenRmEnableUnsupportedGpus=1" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.nvidia = {
    open = true;

    modesetting.enable = true;

    nvidiaSettings = true;

    powerManagement.enable = false;

    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
  };
}
