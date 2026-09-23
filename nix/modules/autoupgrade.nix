{
  config,
  lib,
  ...
}:

let
  cfg = config.turbo;
in
{
  assertions = [
    {
      assertion = cfg.flakeUrl != null && cfg.hostName != null;
      message = ''
        modules/autoupgrade.nix needs turbo.flakeUrl and turbo.hostName, since
        it has nothing else to identify what to build. Set them where this host
        is defined in flake.nix.
      '';
    }
  ];

  system.autoUpgrade = {
    enable = true;
    flake = "${cfg.flakeUrl}#${cfg.hostName}";

    dates = "04:00";
    randomizedDelaySec = "45min";

    operation = "switch";

    allowReboot = false;

    persistent = true;
  };
}
