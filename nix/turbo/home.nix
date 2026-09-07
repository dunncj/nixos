# turbo's user environment. Wired in from ../flake.nix as a NixOS
# home-manager module, so it is applied by `nb`, not by a separate
# `home-manager switch`.
#
# System-wide counterparts deliberately NOT duplicated here:
#   neovim, tmux  -> ../modules/turbo.nix (needed by root and rescue logins)
#   vim/wget/curl -> ../hosts/agartha/configuration.nix
{ pkgs, ... }:

{
  home.username = "turbo";
  home.homeDirectory = "/home/turbo";

  # Set once at install time; not a "which release am I on" knob.
  home.stateVersion = "24.05";

  home.packages = with pkgs; [
    bat
    eza
    fastfetch
    fd
    fzf
    htop
    jq
    ripgrep
    rustup
    tree
  ];

  # EDITOR is already set system-wide by programs.neovim.defaultEditor.
  home.sessionVariables = {
    PAGER = "less -FRX";
  };

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    history = {
      size = 10000;
      save = 10000;
      ignoreDups = true;
      share = true;
    };

    shellAliases = {
      ll = "eza -la --git";
      gs = "git status";
      gc = "git commit";
      gco = "git checkout";
      v = "nvim";

      # /etc/rancher/k3s/k3s.yaml is root-only, so the kubeconfig exported in
      # ../modules/k3s.nix is unreadable as turbo; go through k3s itself.
      k = "sudo k3s kubectl";
    };

    initContent = ''
      # Emacs keys, explicitly: setting EDITOR to a vi-ish name would otherwise
      # make zsh pick vi mode.
      bindkey -e

      # Match the tokyonight background the editors use.
      printf '\e]11;#1a1b26\a'
    '';
  };

  programs.git = {
    enable = true;
    settings = {
      user.name = "Cameron Dunn";
      user.email = "cameron@camerondunn.net";
      init.defaultBranch = "main";
      pull.rebase = false;
    };
  };

  programs.ssh = {
    enable = true;
    # The module's implicit defaults are on their way out and warn if left on.
    enableDefaultConfig = false;
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      add_newline = false;
      format = "$directory$character";
      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };
      git_branch.format = "[$symbol$branch]($style) ";
      directory = {
        truncation_length = 3;
        truncate_to_repo = false;
      };
    };
  };

  programs.home-manager.enable = true;
}
