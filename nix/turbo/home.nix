# turbo's environment - the whole of it.
#
# This profile is what makes a machine turbo's, so everything personal lives
# here rather than in the system layer: editor, shell, multiplexer, git, and
# CLI tooling. The system config (../hosts/agartha) stays minimal and carries
# nothing that is specific to how this user works.
#
# Applied by `nb` as a NixOS home-manager module, not a separate
# `home-manager switch`.
{ lib, pkgs, ... }:

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
    gh
    htop
    jq
    ripgrep
    rustup
    tree
  ];

  home.sessionVariables = {
    PAGER = "less -FRX";
  };

  # defaultEditor exports EDITOR for this profile.
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    # The config below is pure Lua and uses no remote plugins, so skip the
    # Ruby/Python/Node providers rather than dragging them into the closure.
    # (These also become the upstream defaults at stateVersion 26.05.)
    withRuby = false;
    withPython3 = false;
    withNodeJs = false;

    plugins = with pkgs.vimPlugins; [
      tokyonight-nvim
      (nvim-treesitter.withPlugins (
        p: with p; [
          bash
          c
          cpp
          css
          diff
          dockerfile
          git_config
          git_rebase
          gitattributes
          gitcommit
          gitignore
          go
          gomod
          gosum
          graphql
          hcl
          helm
          html
          http
          javascript
          jq
          jsdoc
          json
          json5
          lua
          make
          markdown
          markdown_inline
          nix
          printf
          python
          regex
          rust
          sql
          ssh_config
          terraform
          toml
          tsx
          typescript
          vim
          vimdoc
          xml
          yaml
        ]
      ))
    ];

    initLua = ''
      vim.g.mapleader = " "

      -- Line numbers
      vim.opt.number = true
      vim.opt.relativenumber = true

      -- Indentation
      vim.opt.tabstop = 4
      vim.opt.shiftwidth = 4
      vim.opt.softtabstop = 4
      vim.opt.expandtab = true
      vim.opt.smartindent = true

      -- Search
      vim.opt.ignorecase = true
      vim.opt.smartcase = true
      vim.opt.hlsearch = false
      vim.opt.incsearch = true

      -- UI
      vim.cmd.colorscheme("tokyonight-night")
      vim.opt.termguicolors = true
      vim.opt.cursorline = true
      vim.opt.signcolumn = "yes"
      vim.opt.wrap = false
      vim.opt.scrolloff = 8

      -- Misc
      vim.opt.mouse = "a"
      vim.opt.clipboard = "unnamedplus"
      vim.opt.splitbelow = true
      vim.opt.splitright = true
      vim.opt.swapfile = false
      vim.opt.undofile = true
      vim.opt.updatetime = 250

      -- Keymaps
      local map = vim.keymap.set

      map("n", "<leader>t", "<cmd>:Ex<CR>")

      map("n", "<leader>w", "<cmd>w<CR>")
      map("n", "<leader>q", "<cmd>q<CR>")
      map("n", "<leader>x", "<cmd>x<CR>")

      map("n", "<C-h>", "<C-w>h")
      map("n", "<C-j>", "<C-w>j")
      map("n", "<C-k>", "<C-w>k")
      map("n", "<C-l>", "<C-w>l")
    '';
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
}
