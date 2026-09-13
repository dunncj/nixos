# turbo's interactive shell, on every platform.
#
# Split out of ./system.nix because that file is a NixOS module and the MacBook
# is nix-darwin. ../flake.nix hands amarout the turbo *package* - nvim, eza,
# the starship and git wrappers - but a package is only binaries. None of the
# configuration that makes them behave came with it, so the shell on the
# MacBook had no aliases, no explicit keybindings, no direnv hook and no
# starship prompt, while both Linux boxes had all four. That is not a macOS
# quirk; it is this repo having put the configuration somewhere macOS could
# not reach.
#
# Everything here uses only options that NixOS and nix-darwin both provide, so
# each can import it. Anything platform-specific stays with its platform:
# histSize, setOptions, autosuggestions and syntaxHighlighting are NixOS
# programs.zsh settings with no nix-darwin equivalent and remain in
# ./system.nix.
{ lib, ... }:

let
  # One list, emitted as `alias` lines rather than set through
  # programs.zsh.shellAliases (NixOS) or environment.shellAliases (darwin):
  # those are different options with different scopes on the two platforms,
  # and keeping a copy in each is how the two drift apart.
  aliases = {
    ll = "eza -la --git";
    gs = "git status";
    gc = "git commit";
    gco = "git checkout";
    v = "nvim";

    # /etc/rancher/k3s/k3s.yaml is root-only, so the kubeconfig exported in
    # ../modules/k3s.nix is unreadable as turbo; go through k3s itself. Only
    # meaningful on shambhala, harmless elsewhere - an alias to a command that
    # is not installed costs nothing until it is typed.
    k = "sudo k3s kubectl";
  };

  aliasLines = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: value: "alias ${name}=${lib.escapeShellArg value}") aliases
  );
in
{
  programs.zsh = {
    enable = true; # also required before zsh may be turbo's login shell

    interactiveShellInit = ''
      # Set here rather than in a session-variable option so they stay with
      # turbo's shell instead of applying to root as well.
      export EDITOR=nvim
      export PAGER='less -FRX'

      # Emacs keys, explicitly: EDITOR is a vi-ish name, which would
      # otherwise make zsh pick vi mode.
      bindkey -e

      # Match the tokyonight background the editor uses.
      printf '\e]11;#1a1b26\a'

      ${aliasLines}

      # direnv lives in turbo's profile, not the system one, so this file is
      # read by shells that may not have it (a rescue zsh as root). Guard
      # rather than spew errors.
      if command -v direnv >/dev/null; then
        eval "$(direnv hook zsh)"
      fi
    '';

    # Must be promptInit, not interactiveShellInit: on NixOS the module's
    # default promptInit runs `prompt suse` afterwards, which would overwrite
    # anything starship set.
    promptInit = ''
      if command -v starship >/dev/null; then
        eval "$(starship init zsh)"
      fi
    '';
  };
}
