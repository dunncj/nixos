# amarout - Cameron's day-to-day MacBook. nix-darwin only, no home-manager:
# the portable tool/editor package it pulls in lives in ../../turbo, wired up
# in ../../flake.nix rather than here so this file stays host-only settings.
{ pkgs, ... }:
{
  nixpkgs.hostPlatform = "aarch64-darwin";

  # Who owns the machine config (used by some nix-darwin modules).
  system.primaryUser = "turbo";

  # This machine calls itself Camerons-MacBook-Pro-3811, which is macOS's
  # default built from the owner's full name at setup. It leaks into two
  # visible places and both were complained about: the shell prompt, because
  # starship's hostname module reads the system hostname, and `tailscale
  # status`, because tailscale registers a node under the host's hostname.
  # One name, one fix.
  #
  # All three are set because macOS keeps three and they drift apart
  # otherwise: computerName is the Finder/AirDrop name, hostName is the
  # scutil HostName that shells and tailscale read, and localHostName is the
  # Bonjour name (amarout.local). ../../nodes.nix already calls this node
  # amarout, so this makes the machine agree with the registry rather than the
  # other way round.
  #
  # Renaming does not affect anything the mesh depends on: ../../modules/
  # mesh.nix writes every node's names into /etc/hosts from the registry and
  # pins host keys by those names, so `ssh ama` resolves without MagicDNS and
  # the ssh host key is untouched by a hostname change.
  networking.computerName = "amarout";
  networking.hostName = "amarout";
  networking.localHostName = "amarout";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Works around a version-skew bug between nixpkgs-unstable's
  # nixos-render-docs and nix-darwin/master's manual-building script
  # (nixos-render-docs dropped --sidebar-depth; nix-darwin still passes it).
  # Harmless to disable: nobody reads `man darwin-config` off this machine.
  documentation.enable = false;

  # Required; bump only when you understand the changelog impact. Carried
  # over unchanged from the config this replaced.
  system.stateVersion = 6;

  # Puts cargo/rustc/rustup on PATH via /run/current-system/sw/bin.
  # Uses the toolchains already installed under ~/.rustup.
  environment.systemPackages = [ pkgs.rustup ];
}
