# turbo's shell, as plain strings.
#
# Deliberately not a module. The same text has to reach three kinds of machine
# and only one of them has a module system pointed at it:
#
#   NixOS        ./shell.nix -> programs.zsh        (writes /etc/zshrc)
#   nix-darwin   ./shell.nix -> programs.zsh        (writes /etc/zshrc)
#   anything     ./package.nix -> share/turbo/zshrc (sourced from ~/.zshrc)
#                else          and `turbo-shell-init`
#
# A NixOS module cannot be imported by a Debian box with nix installed, so
# anything expressed as module options is automatically unavailable to the
# third case. Keeping the text here, and the wiring in the callers, is what
# lets one definition serve all three.
{ lib }:

let
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
  # Everything here guards on the command existing. On NixOS these tools are
  # guaranteed by the same config that installs this file, but on a foreign
  # machine the profile may be half-installed or not on PATH yet, and a shell
  # that errors on every prompt is worse than one missing an alias.
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

  # Kept separate because NixOS needs it in promptInit specifically: the
  # module's default promptInit runs `prompt suse` afterwards, which would
  # overwrite anything starship set. Elsewhere the two are simply concatenated.
  promptInit = ''
    if command -v starship >/dev/null; then
      eval "$(starship init zsh)"
    fi
  '';
}
