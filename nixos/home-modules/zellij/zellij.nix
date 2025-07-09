{ config, pkgs, wayland, ... }:

{

  home.packages = with pkgs; [
    zellij
  ];


  home.file.".config/zellij".source = ./conf;



}
