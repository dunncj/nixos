# The turbo account, and nothing else.
#
# Everything this user actually works with - editor, shell, tmux, git, CLI
# tooling - lives in ../turbo/home.nix. The system layer deliberately carries
# none of it: the home-manager profile is what makes a machine turbo's, so it
# has to be the single place that defines that environment.
{ pkgs, ... }:

{
  users.users.turbo = {
    isNormalUser = true;
    description = "Turbo";
    shell = pkgs.zsh;

    extraGroups = [
      "wheel"
      "networkmanager"
      "docker"
    ];

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILRrMGvIUXrzbm74iexuJz3HM+/NXPQnnQPDcLZ/CdYL turbo@agartha"
    ];
  };
}
