# Unattended upgrades, straight from the default branch on GitHub.
#
# Listed per-host in ../flake.nix rather than folded into base.nix, and
# deliberately only on shambhala. The difference that matters is not what the
# machines are but whether anyone is sitting at them: an unattended switch
# restarts whatever units changed, and doing that under someone mid-task is a
# worse failure than being a few commits behind. myosis rebuilds when its owner
# says so.
#
# It takes the flake reference, not a checkout. Nothing here reads
# turbo.flakePath, so a stale or dirty working tree on the machine cannot
# change what gets deployed - the default branch is the only input. That is the
# same path `nb pull` takes, on a timer.
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

    # No `flags = [ "--refresh" ]` here: the NixOS module already appends
    # --refresh (and the --flake argument) whenever `flake` is set, and passing
    # it again just puts it on the command line twice.

    # Overnight, because this host is only ever driven remotely and a restarted
    # Sunshine or k3s unit mid-session is the thing to avoid. The delay spreads
    # the load if a second host is ever added here.
    dates = "04:00";
    randomizedDelaySec = "45min";

    # `switch`, so the activation happens now and any breakage surfaces while
    # the previous generation is still the boot default to roll back to.
    operation = "switch";

    # Never on its own. A kernel or initrd change simply waits for a reboot
    # someone chose: this box runs a k3s server and a Minecraft server, and an
    # unannounced 4am reboot is a worse outcome than a pending kernel.
    allowReboot = false;

    # The timer catches up after downtime rather than silently skipping a
    # machine that happened to be off at 04:00.
    persistent = true;
  };
}
