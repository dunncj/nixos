{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    wget
    unzip
    cl
    vim
    coreutils-full
  ];
}
