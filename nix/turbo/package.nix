# turbo's environment as a single package.
#
# `nix profile install github:dunncj/nixos#turbo`, `nix shell`, or
# `nix run .#turbo -- nvim` puts the whole toolchain on any machine with nix,
# NixOS or not, without home-manager and without touching $HOME.
#
# What this can and cannot do, honestly:
#
#   - The editor is complete. ./neovim.nix bakes its plugins, lua tree and
#     language servers into the wrapper, so it behaves identically here and
#     under home-manager.
#   - The CLI tools are complete: the same ./tools.nix list the module uses.
#   - The *dotfiles* are not here. zsh, git and tmux read their config from
#     $HOME, and writing to $HOME is an activation step, not something a
#     derivation may do. For those, use the module in ./home.nix.
{
  pkgs,
  flakePath ? null,
  hostName ? null,
}:

let
  neovim = pkgs.callPackage ./neovim.nix { inherit flakePath hostName; };
in
pkgs.buildEnv {
  name = "turbo-env";

  paths = (import ./tools.nix pkgs) ++ [ neovim ];

  meta = {
    description = "turbo's editor and CLI environment as one package";
    platforms = pkgs.lib.platforms.unix;
  };
}
