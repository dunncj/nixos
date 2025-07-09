{ config, pkgs, inputs, ... }:

{

  home.packages = [ (pkgs.writeShellScriptBin "nb" "sudo nixos-rebuild switch --flake ~/nixos#titan") ];


}
