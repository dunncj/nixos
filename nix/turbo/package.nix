{
  pkgs,
  flakePath ? null,
  hostName ? null,
}:

let
  inherit (pkgs) lib;

  neovim = pkgs.callPackage ./neovim.nix { inherit flakePath hostName; };
  wrappers = pkgs.callPackage ./wrappers.nix { };

  shell = import ./shell-init.nix { inherit lib; };

  zshrc = pkgs.writeTextFile {
    name = "turbo-zshrc";
    destination = "/share/turbo/zshrc";
    text = ''
      # turbo's interactive shell, for a machine this flake does not build.
      # Generated from nix/turbo/shell-init.nix -- edit there, not here.
      #
      # Source it from ~/.zshrc, or `eval "$(turbo-shell-init)"`.

      ${shell.interactiveShellInit}

      ${shell.promptInit}
    '';
  };

  shellInitBin = pkgs.writeShellScriptBin "turbo-shell-init" ''
    exec cat ${zshrc}/share/turbo/zshrc
  '';
in
pkgs.buildEnv {
  name = "turbo-env";

  paths = (import ./tools.nix pkgs) ++ [
    neovim
    wrappers.git
    wrappers.tmux
    wrappers.starship
    zshrc
    shellInitBin
  ];

  meta = {
    description = "turbo's editor, tools and config as one package";
    platforms = pkgs.lib.platforms.unix;
  };
}
