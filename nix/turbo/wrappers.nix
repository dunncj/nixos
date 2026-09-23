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
  gitConfig = writeText "gitconfig" (
    lib.generators.toGitINI {
      user = {
        name = "Cameron Dunn";
        email = "cameron@camerondunn.net";
      };

      init.defaultBranch = "main";
      pull.rebase = false;

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

  tmuxConfig = runCommand "tmux.conf" {
    body = tmuxConfigBody;
    passAsFile = [ "body" ];
  } ''substitute "$bodyPath" "$out" --replace-fail '@SELF@' "$out"'';

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
    args = ''--set STARSHIP_CONFIG "${starshipConfig}"'';
  };
}
