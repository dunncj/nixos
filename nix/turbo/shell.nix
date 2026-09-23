{ lib, ... }:

let
  shell = import ./shell-init.nix { inherit lib; };
in
{
  programs.zsh = {
    enable = true;

    inherit (shell) interactiveShellInit promptInit;
  };
}
