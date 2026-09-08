# turbo's environment as a single package.
#
# `nix profile install github:dunncj/nixos?dir=nix#turbo`, `nix shell`, or
# `nix run .#turbo -- nvim` puts the whole toolchain on any machine with nix,
# NixOS or not, and now brings its config with it.
#
# Everything that has config carries it inside its own wrapper - the editor
# via ./neovim.nix, and git/tmux/starship via ./wrappers.nix - so this package
# needs nothing in $HOME and nothing in /etc.
#
# The one exception is zsh: a login shell reads ~/.zshrc or /etc/zshrc, and a
# derivation may write neither. ./system.nix supplies that through the NixOS
# zsh module. Everything else here is self-contained.
{
  pkgs,
  flakePath ? null,
  hostName ? null,
}:

let
  neovim = pkgs.callPackage ./neovim.nix { inherit flakePath hostName; };
  wrappers = pkgs.callPackage ./wrappers.nix { };
in
pkgs.buildEnv {
  name = "turbo-env";

  paths = (import ./tools.nix pkgs) ++ [
    neovim
    wrappers.git
    wrappers.tmux
    wrappers.starship
  ];

  meta = {
    description = "turbo's editor, tools and config as one package";
    platforms = pkgs.lib.platforms.unix;
  };
}
