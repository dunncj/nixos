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
# zsh used to be the one exception: a login shell reads ~/.zshrc or /etc/zshrc
# and a derivation may write neither, so the shell config was available only
# through ./system.nix's NixOS module - which meant the one kind of machine the
# portable package exists for was the one kind that could not have it.
#
# It now ships inside the package too. On a machine this flake does not build:
#
#   nix profile install github:dunncj/nixos?dir=nix#turbo
#   echo 'eval "$(turbo-shell-init)"' >> ~/.zshrc
#
# Same text as the NixOS and nix-darwin hosts get, from ./shell-init.nix. The
# file is also at share/turbo/zshrc for anyone who would rather `source` a path
# than run a command.
{
  pkgs,
  flakePath ? null,
  hostName ? null,
}:

let
  inherit (pkgs) lib;

  neovim = pkgs.callPackage ./neovim.nix { inherit flakePath hostName; };
  wrappers = pkgs.callPackage ./wrappers.nix { };

  shell = import ./shell-init.nix { inherit lib; };

  # promptInit and interactiveShellInit are separate only because NixOS needs
  # the prompt in its own option; with no module system in the way they are
  # just two halves of one file, in that order.
  zshrc = pkgs.writeTextFile {
    name = "turbo-zshrc";
    destination = "/share/turbo/zshrc";
    text = ''
      # turbo's interactive shell, for a machine this flake does not build.
      # Generated from nix/turbo/shell-init.nix -- edit there, not here.
      #
      # Source it from ~/.zshrc, or `eval "$(turbo-shell-init)"`.

      ${shell.interactiveShellInit}

      ${shell.promptInit}
    '';
  };

  # The idiomatic shape, the same one starship and direnv use: a command that
  # prints the snippet, so ~/.zshrc never has to name a nix store path that
  # changes on every update.
  shellInitBin = pkgs.writeShellScriptBin "turbo-shell-init" ''
    exec cat ${zshrc}/share/turbo/zshrc
  '';
in
pkgs.buildEnv {
  name = "turbo-env";

  paths = (import ./tools.nix pkgs) ++ [
    neovim
    wrappers.git
    wrappers.tmux
    wrappers.starship
    zshrc
    shellInitBin
  ];

  meta = {
    description = "turbo's editor, tools and config as one package";
    platforms = pkgs.lib.platforms.unix;
  };
}
