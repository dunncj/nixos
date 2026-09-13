# What every NixOS host in this repo wants, so a host config only has to state
# what makes it that host.
#
# Extracted when myosis arrived and these ten lines would otherwise have been
# copied verbatim into a second host. Nothing here is a judgement call - it is
# the intersection of what shambhala and myosis were already both setting, with
# identical values. Anything a host might reasonably want to differ on stays in
# the host config (boot.loader.systemd-boot.configurationLimit is the current
# example: myosis shares a 200 MB ESP with Windows, shambhala does not).
#
# When both hosts end up wanting the same thing, it belongs here (or in a shared
# module they both import) rather than being written twice - two copies drift,
# and a setting added to one host is a setting silently missing from the other.
{ pkgs, ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # shambhala needs it for steam, myosis for the NVIDIA driver.
  nixpkgs.config.allowUnfree = true;

  networking.networkmanager.enable = true;
  hardware.enableRedistributableFirmware = true;

  # `nb` sudos to itself on every rebuild, and these are single-user machines.
  security.sudo.wheelNeedsPassword = false;

  # How you reach either machine. turbo/system.nix declares the authorized keys,
  # so sshd here is enough to make a host reachable from the repo alone; NixOS
  # leaves password auth off by default.
  services.openssh.enable = true;

  services.tailscale.enable = true;
  networking.firewall.allowedUDPPorts = [ 41641 ]; # tailscale

  # Claude Code CLI - runs latest version via npx
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "claude" ''
      exec ${pkgs.nodejs}/bin/npx -y @anthropic-ai/claude-code "$@"
    '')
  ];
}
