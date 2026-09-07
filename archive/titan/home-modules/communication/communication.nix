{ config, pkgs, home, ... }:

{
  home.packages = with pkgs; [
    discord
    slack
    zoom
  ];
}
