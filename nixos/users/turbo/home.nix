{ config, pkgs, ... }:

{
	imports = [
	#./sway.nix

	];

	

  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "turbo";
  home.homeDirectory = "/home/turbo";
  

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "24.05"; # Please read the comment before changing.

  #virtual machine
  home.pointerCursor = {
    gtk.enable = true;
    package = pkgs.vanilla-dmz;
    name = "Vanilla-DMZ";
  };
  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
  wl-clipboard
  gh
  tokyo-night-gtk
  glib
  nodejs
  bun
  rustup
  ripgrep
    # # Adds the 'hello' command to your environment. It prints a friendly
    # # "Hello, world!" when run.
    # pkgs.hello

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?/

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
  ];



	programs.git = {
	enable = true;
	userName = "Cameron Dunn";
	userEmail = "turbo25037@gmail.com";
	};

  programs.home-manager.enable = true;

# programs.zsh = {
          # enable = true;
  # };
   programs.alacritty = {
   	enable = true;
 	settings = {
 		font.size = 11;
 		shell.program = "${pkgs.zsh}/bin/zsh";
        colors.primary.background = "#1a1b26";
        
 	};
   };


}
