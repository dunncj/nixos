# turbo's interactive shell, wired into a module system.
#
# Split out of ./system.nix because that file is a NixOS module and the MacBook
# is nix-darwin. ../flake.nix hands amarout the turbo *package* - nvim, eza,
# the starship and git wrappers - but a package is only binaries. None of the
# configuration that makes them behave came with it, so the shell on the
# MacBook had no aliases, no explicit keybindings, no direnv hook and no
# starship prompt, while both Linux boxes had all four.
#
# This file uses only options that NixOS and nix-darwin both provide, so each
# can import it. Anything platform-specific stays with its platform: histSize,
# setOptions, autosuggestions and syntaxHighlighting are NixOS programs.zsh
# settings with no nix-darwin equivalent and remain in ./system.nix.
#
# The text itself is in ./shell-init.nix, which is not a module, because
# ./package.nix has to ship the same thing to machines that have no module
# system at all.
{ lib, ... }:

let
  shell = import ./shell-init.nix { inherit lib; };
in
{
  programs.zsh = {
    enable = true; # also required before zsh may be turbo's login shell

    inherit (shell) interactiveShellInit promptInit;
  };
}
