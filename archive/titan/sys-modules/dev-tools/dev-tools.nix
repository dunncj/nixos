{ config, pkgs, ...}:

{
programs.nix-ld.enable = true;

  # Sets up all the libraries to load
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc # commonly needed
    zlib # commonly needed
    openssl # commonly needed
  ];

    environment.systemPackages = with pkgs; [
        git
        cargo
        zig
        clang
        gnumake
        gcc
        cmake
        zsh
        fzf
        neovim
        go
        php
        python3




    ];

    programs.zsh = {
        enable = true;
        ohMyZsh = {
            enable = true;
            theme = "fwalch";
            plugins = [
                "sudo"
            ];
        };
    };

}
