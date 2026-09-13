# Unattended upgrades, straight from the default branch on GitHub.
#
# Every NixOS host here gets this, from ../flake.nix's mkLinuxHost. It was
# shambhala-only for one commit, on the argument that an unattended switch
# under someone sitting at the machine is worse than being a few commits
# behind. The instruction is that the config should be the same everywhere,
# and that is the stronger argument: a host excluded from this is a host that
# silently drifts until someone remembers it, and "which machines are current?"
# stops having an answer. Convergence is the point of the whole registry.
#
# It takes the flake reference, not a checkout. Nothing here reads
# turbo.flakePath, so a stale or dirty working tree on the machine cannot
# change what gets deployed - the default branch is the only input. That is the
# same path `nb pull` takes, on a timer.
#
# The trade this accepts, worth naming because it is now on a workstation too:
# anything pushed to the default branch reaches every machine within a day
# without anyone deciding to deploy it. allowReboot = false and
# operation = "switch" are what keep that recoverable - see below.
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

    # Overnight, when nobody is streaming to shambhala or sat at myosis. The
    # randomized delay means the hosts do not all wake and fetch at once.
    dates = "04:00";
    randomizedDelaySec = "45min";

    # `switch`, so the activation happens now and any breakage surfaces while
    # the previous generation is still the boot default to roll back to.
    operation = "switch";

    # Never on its own. A kernel or initrd change simply waits for a reboot
    # someone chose. shambhala runs a k3s server and a Minecraft server, and
    # myosis dual-boots off a shared disk; an unannounced 4am reboot is a worse
    # outcome than a pending kernel on either of them.
    allowReboot = false;

    # The timer catches up after downtime rather than silently skipping a
    # machine that happened to be off at 04:00.
    persistent = true;
  };
}
