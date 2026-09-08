# amarout - Cameron's day-to-day MacBook. nix-darwin only, no home-manager:
# the portable tool/editor package it pulls in lives in ../../turbo, wired up
# in ../../flake.nix rather than here so this file stays host-only settings.
{ pkgs, ... }:
{
  nixpkgs.hostPlatform = "aarch64-darwin";

  # Who owns the machine config (used by some nix-darwin modules).
  system.primaryUser = "camerondunn";

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
