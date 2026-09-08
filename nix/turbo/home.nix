# turbo's environment, as a reusable home-manager module.
#
# This is the portable unit: import it on any machine (as a NixOS
# home-manager module, or standalone via homeConfigurations) and that machine
# becomes turbo's. Nothing in here is specific to agartha - the only
# host-dependent bits are the two options below.
#
# Shares ./tools.nix and ./neovim.nix with ./package.nix, so the module and
# the standalone environment package cannot drift apart.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.turbo;

  neovim = pkgs.callPackage ./neovim.nix {
    inherit (cfg) flakePath hostName;
  };
in
{
  options.turbo = {
    flakePath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/home/turbo/nix";
      description = ''
        Absolute path to this flake on the target machine, used by nixd to
        offer NixOS and home-manager option completion. Leave null on a
        machine this repo does not build; nixd still runs without it.
      '';
    };

    hostName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "agartha";
      description = ''
        Which `nixosConfigurations` entry nixd should evaluate for option
        completion. Only meaningful alongside `turbo.flakePath`.
      '';
    };
  };

  config = {
    home.username = lib.mkDefault "turbo";
    home.homeDirectory = lib.mkDefault "/home/turbo";

    # Set once at install time; not a "which release am I on" knob.
    home.stateVersion = lib.mkDefault "24.05";

    home.packages = (import ./tools.nix pkgs) ++ [ neovim ];

    home.sessionVariables = {
      PAGER = "less -FRX";
      EDITOR = "nvim";
    };

    programs.tmux = {
      enable = true;
      terminal = "tmux-256color";
      historyLimit = 100000;
      keyMode = "vi";
      escapeTime = 10;

      extraConfig = ''
        set -g status off

        # home-manager writes this file, so reload from XDG rather than /etc.
        bind r source-file ~/.config/tmux/tmux.conf \; display-message "Reloaded"

        bind h select-pane -L
        bind j select-pane -D
        bind k select-pane -U
        bind l select-pane -R

        bind -r H resize-pane -L 5
        bind -r J resize-pane -D 5
        bind -r K resize-pane -U 5
        bind -r L resize-pane -R 5

        set -ga terminal-overrides ",*:Tc"

        set -g status-position bottom
        set -g status-interval 5
      '';
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
        # Emacs keys, explicitly: EDITOR is a vi-ish name, which would otherwise
        # make zsh pick vi mode.
        bindkey -e

        # Match the tokyonight background the editor uses.
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

        # Authenticate pushes through the gh token rather than a second
        # credential store. `gh auth setup-git` cannot be used here: it writes to
        # the global gitconfig, which home-manager owns and mounts read-only.
        credential."https://github.com".helper = "!${lib.getExe pkgs.gh} auth git-credential";
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
  };
}
