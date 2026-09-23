{ ... }:

{
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
  };

  turbo.extraGroups = [ "docker" ];
}
