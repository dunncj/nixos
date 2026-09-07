# The turbo account, plus the two editors that need to work before any
# home-manager generation exists. Everything else about this user's
# environment lives in ../turbo/home.nix.
{ pkgs, ... }:

{
  users.users.turbo = {
    isNormalUser = true;
    description = "Turbo";
    shell = pkgs.zsh;

    extraGroups = [
      "wheel"
      "networkmanager"
      "docker"
    ];

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILRrMGvIUXrzbm74iexuJz3HM+/NXPQnnQPDcLZ/CdYL turbo@agartha"
    ];
  };

  programs.tmux = {
    enable = true;
    terminal = "tmux-256color";
    historyLimit = 100000;

    extraConfig = ''
      set -g status off

      setw -g mode-keys vi
      bind r source-file /etc/tmux.conf \; display-message "Reloaded"

      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5

      set -sg escape-time 10
      set -ga terminal-overrides ",*:Tc"

      set -g status-position bottom
      set -g status-interval 5
    '';
  };

  # System-level rather than home-manager so that a root shell and a rescue
  # login get the same configured editor.
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    configure = {
      packages.myPlugins = with pkgs.vimPlugins; {
        start = [
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
              helm
              hcl
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
      };

      customRC = ''
        lua << EOF
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
        EOF
      '';
    };
  };
}
