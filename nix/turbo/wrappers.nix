# git, tmux and starship with their config baked in.
#
# Same idea as ./neovim.nix: the config travels inside the derivation instead
# of being written into $HOME or /etc, so these behave identically whether
# they arrive through ./system.nix or through a bare
# `nix profile install ...#turbo` on a machine that has never seen this repo.
#
# It also keeps root clean. The NixOS programs.{git,tmux,starship,direnv}
# modules all push their package into environment.systemPackages, which would
# put these on root's PATH; wrapping them here means they exist only in
# turbo's own profile.
{
  lib,
  formats,
  makeWrapper,
  runCommand,
  symlinkJoin,
  writeText,

  git,
  tmux,
  starship,
}:

let
  # GIT_CONFIG_SYSTEM replaces /etc/gitconfig, so a per-user ~/.gitconfig
  # still layers on top and `git config --global` keeps working.
  gitConfig = writeText "gitconfig" (
    lib.generators.toGitINI {
      user = {
        name = "Cameron Dunn";
        email = "cameron@camerondunn.net";
      };

      init.defaultBranch = "main";
      pull.rebase = false;

      # Authenticate pushes through the gh token rather than a second
      # credential store. gh is resolved from PATH so this keeps working if
      # the profile's gh is upgraded independently.
      credential."https://github.com".helper = "!gh auth git-credential";
    }
  );

  tmuxConfigBody = ''
    set -g default-terminal "tmux-256color"
    set -g history-limit 100000
    set -sg escape-time 10
    setw -g mode-keys vi

    set -g status off

    bind r source-file @SELF@ \; display-message "Reloaded"

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

  # Built with runCommand rather than writeText so the reload binding can
  # point at the config's own final store path.
  tmuxConfig = runCommand "tmux.conf" {
    body = tmuxConfigBody;
    passAsFile = [ "body" ];
  } ''substitute "$bodyPath" "$out" --replace-fail '@SELF@' "$out"'';

  # Deliberately minimal: user, host and a prompt character, nothing else.
  # Starship's default format would otherwise add a git branch on every
  # directory ($HOME is itself a git repo) and a Java version in $HOME
  # (server.jar makes it look like a Java project).
  starshipConfig = (formats.toml { }).generate "starship.toml" {
    add_newline = false;
    format = "$username$hostname$character";

    username = {
      show_always = true;
      format = "[$user]($style)";
      style_user = "bold green";
      style_root = "bold red";
    };

    hostname = {
      ssh_only = false;
      format = "@[$hostname]($style) ";
      style = "bold green";
    };

    character = {
      success_symbol = "[❯](bold green)";
      error_symbol = "[❯](bold red)";
    };
  };

  # wrapProgram refuses to operate on the symlinks symlinkJoin creates, so
  # each wrapped entry point is removed and recreated as a real wrapper.
  wrap =
    {
      name,
      package,
      binary,
      args,
    }:
    symlinkJoin {
      inherit name;
      paths = [ package ];
      nativeBuildInputs = [ makeWrapper ];
      postBuild = ''
        rm "$out/bin/${binary}"
        makeWrapper "${package}/bin/${binary}" "$out/bin/${binary}" ${args}
      '';
    };
in
{
  git = wrap {
    name = "git-turbo";
    package = git;
    binary = "git";
    args = ''--set GIT_CONFIG_SYSTEM "${gitConfig}"'';
  };

  tmux = wrap {
    name = "tmux-turbo";
    package = tmux;
    binary = "tmux";
    args = ''--add-flags "-f ${tmuxConfig}"'';
  };

  starship = wrap {
    name = "starship-turbo";
    package = starship;
    binary = "starship";
    # --set, not --set-default: a stale STARSHIP_CONFIG in the environment
    # (systemd user managers keep imported values long after the file that set
    # them is gone) would otherwise silently defeat this config and drop
    # starship back to its defaults.
    args = ''--set STARSHIP_CONFIG "${starshipConfig}"'';
  };
}
