# turbo, as a NixOS module: the account and the whole environment.
#
# This is the portable unit - import it on any NixOS machine and that machine
# becomes turbo's. It replaces the home-manager module that used to live in
# ./home.nix.
#
# Packages come from ./package.nix and go into users.users.turbo.packages, so
# they land in /etc/profiles/per-user/turbo and root still gets none of them.
# The dotfiles home-manager used to write into $HOME now ride inside the
# wrappers in ./wrappers.nix, so nothing here writes to $HOME or /etc. The one
# exception is zsh: a login shell reads /etc/zshrc, which the NixOS zsh module
# below supplies.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.turbo;

  env = import ./package.nix {
    inherit pkgs;
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
        offer NixOS option completion. Leave null on a machine this repo does
        not build; nixd still runs without it.
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

    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "docker" ];
      description = "Host-specific groups to add turbo to, beyond the defaults.";
    };
  };

  config = {
    users.users.turbo = {
      isNormalUser = true;
      description = "Turbo";
      shell = pkgs.zsh;

      extraGroups = [
        "wheel"
        "networkmanager"
      ]
      ++ cfg.extraGroups;

      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILRrMGvIUXrzbm74iexuJz3HM+/NXPQnnQPDcLZ/CdYL turbo@agartha"
      ];

      # The whole environment as one package. Per-user, so root's PATH is
      # untouched.
      packages = [ env ];
    };

    programs.zsh = {
      enable = true; # also required before zsh may be turbo's login shell

      histSize = 10000;
      setOptions = [
        "HIST_IGNORE_DUPS"
        "SHARE_HISTORY"
        "HIST_FCNTL_LOCK"
      ];

      autosuggestions.enable = true;
      syntaxHighlighting.enable = true;

      shellAliases = {
        ll = "eza -la --git";
        gs = "git status";
        gc = "git commit";
        gco = "git checkout";
        v = "nvim";

        # /etc/rancher/k3s/k3s.yaml is root-only, so the kubeconfig exported
        # in ../modules/k3s.nix is unreadable as turbo; go through k3s itself.
        k = "sudo k3s kubectl";
      };

      interactiveShellInit = ''
        # Set here rather than environment.sessionVariables so they stay with
        # turbo's shell instead of applying to root as well.
        export EDITOR=nvim
        export PAGER='less -FRX'

        # Emacs keys, explicitly: EDITOR is a vi-ish name, which would
        # otherwise make zsh pick vi mode.
        bindkey -e

        # Match the tokyonight background the editor uses.
        printf '\e]11;#1a1b26\a'

        # direnv lives in turbo's profile, not the system one, so this file is
        # read by shells that may not have it (a rescue zsh as root). Guard
        # rather than spew errors.
        if command -v direnv >/dev/null; then
          eval "$(direnv hook zsh)"
        fi
      '';

      # Must be promptInit, not interactiveShellInit: the module's default
      # promptInit runs `prompt suse` afterwards, which would overwrite
      # anything starship set.
      promptInit = ''
        if command -v starship >/dev/null; then
          eval "$(starship init zsh)"
        fi
      '';
    };

  };
}
