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
  imports = [ ./shell.nix ];

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

    flakeUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "github:dunncj/nixos?dir=nix";
      description = ''
        Where this flake lives upstream, for `nb pull`. A flake reference is
        all nixos-rebuild needs -- a machine can switch straight from GitHub
        with no checkout, no git, and no working tree to be out of date.

        Leave null to drop `nb pull`; the local path-based commands do not
        depend on it.
      '';
    };

    hostName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "shambhala";
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

      packages = [ env ];
    };

    systemd.tmpfiles.rules = [
      "f ${config.users.users.turbo.home}/.zshrc 0644 turbo users - # personal zsh additions - system config lives in /etc/zshrc, from nix/turbo/system.nix"
    ];

    programs.zsh = {
      histSize = 10000;
      setOptions = [
        "HIST_IGNORE_DUPS"
        "SHARE_HISTORY"
        "HIST_FCNTL_LOCK"
      ];

      autosuggestions.enable = true;
      syntaxHighlighting.enable = true;
    };

  };
}
