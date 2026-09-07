{ config, pkgs, ...}:

{
  gtk = {
    enable = true;
    theme = {
      name = "Tokyonight-Dark-B";
      package = pkgs.tokyonight-gtk-theme;
    };
  };

  programs.alacritty = {
    enable = true;
    settings = {
      font.size = 11;
      shell.program = "${pkgs.zsh}/bin/zsh";
      colors.primary.background = "#1a1b26";

    };
  };

    programs.zathura.enable = true;
}
