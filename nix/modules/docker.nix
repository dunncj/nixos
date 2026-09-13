# Docker, and turbo's membership of the group that can use it.
#
# The group is set here rather than passed through turbo.extraGroups at the call
# site in ../flake.nix: the group is only meaningful because this module is
# imported, so the two belong together. Adding docker to a host is one line in
# the module list, with nothing to remember elsewhere.
#
# Worth being explicit about: membership of `docker` is root-equivalent, since
# the daemon runs as root and will bind-mount anything you ask it to. That is
# accepted here because both hosts also have passwordless sudo for turbo, so it
# grants nothing that was not already available.
{ ... }:

{
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
  };

  turbo.extraGroups = [ "docker" ];
}
