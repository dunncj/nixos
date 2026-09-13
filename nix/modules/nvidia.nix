# The NVIDIA proprietary driver.
#
# Why this module exists rather than just letting nouveau drive the card:
# nouveau implements neither HDMI 2.1 FRL nor DSC, so it is stuck on HDMI 2.0
# TMDS signalling and its highest 4K mode is VIC 97 (3840x2160@60, 594 MHz).
# The monitor's DisplayID block advertises 3840x2160@144 at a 1278.72 MHz
# pixel clock - more than twice the TMDS ceiling - so that mode is reachable
# only over FRL with DSC, which is to say only on this driver.
#
# Confirmed from the EDID before writing any of this: the HDMI Forum VSDB
# reports "Supports VESA DSC 1.2a" and FRL up to 12 Gbps on 4 lanes.
{ config, ... }:

{
  # Also blacklists nouveau, so the two drivers cannot both claim the card.
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics = {
    enable = true;
    # 32-bit GL, for wine and for anything from Steam's back catalogue.
    enable32Bit = true;
  };

  hardware.nvidia = {
    # Mandatory on Blackwell (RTX 50-series, GB2xx), not a preference: the
    # closed kernel module has no support for these chips at all. Only the
    # open one binds.
    open = true;

    # Sets nvidia-drm.modeset=1, without which there is no Wayland session -
    # and Plasma runs Wayland here.
    modesetting.enable = true;

    nvidiaSettings = true;

    # A desktop that is always on AC. The suspend/resume VRAM save-and-restore
    # hooks only add ways for a resume to come back with a black screen.
    powerManagement.enable = false;

    # 580.119.02 in this pinned nixpkgs. `production` rather than `latest`
    # (590.48.01) on purpose - both support Blackwell, and this is the branch
    # that gets fixes rather than features. Switch to
    # `nvidiaPackages.latest` if a newer card or a DSC fix needs it.
    package = config.boot.kernelPackages.nvidiaPackages.production;
  };
}
