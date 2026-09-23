{ lib }:

let
  aliases = {
    ll = "eza -la --git";
    gs = "git status";
    gc = "git commit";
    gco = "git checkout";
    v = "nvim";

    k = "sudo k3s kubectl";
  };

  aliasLines = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: value: "alias ${name}=${lib.escapeShellArg value}") aliases
  );
in
{
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
    # read by shells that may not have it (a rescue zsh as root, or a foreign
    # machine before the profile is installed). Guard rather than spew errors.
    if command -v direnv >/dev/null; then
      eval "$(direnv hook zsh)"
    fi
  '';

  promptInit = ''
    if command -v starship >/dev/null; then
      eval "$(starship init zsh)"
    fi
  '';
}
