# turbo's editor, as one self-contained derivation.
#
# Everything is inside the wrapper: plugins, the lua tree, and the language
# servers on its own PATH. It needs nothing in $HOME and ignores
# ~/.config/nvim entirely, so it behaves the same wherever it is run - via
# home.packages here, via the environment package in ./package.nix, or with a
# bare `nix run` on a machine that has never heard of this config.
{
  lib,
  runCommand,
  writeText,
  wrapNeovim,
  neovim-unwrapped,
  vimPlugins,

  # telescope shells out to these
  fd,
  ripgrep,

  bash-language-server,
  basedpyright,
  clang-tools,
  dockerfile-language-server,
  emmet-language-server,
  gopls,
  helm-ls,
  lua-language-server,
  nixd,
  nixfmt,
  rust-analyzer,
  terraform-ls,
  typescript-language-server,
  vscode-langservers-extracted,
  yaml-language-server,

  # Which flake nixd should evaluate for NixOS/home-manager option completion.
  # Leave both null on a machine this repo does not build; nixd still runs,
  # just without option completion.
  flakePath ? null,
  hostName ? null,
}:

let
  # Generated rather than checked in, because it is the only part of the lua
  # tree that differs between machines.
  hostLua = writeText "host.lua" ''
    return {
        flake = ${if flakePath == null then "nil" else ''"${flakePath}"''},
        hostname = ${if hostName == null then "nil" else ''"${hostName}"''},
    }
  '';

  # A plain directory with lua/ in it is a vim plugin as far as 'packages' is
  # concerned, which is the tidiest way to get this tree onto the runtimepath.
  runtime = runCommand "turbo-nvim-runtime" { } ''
    mkdir -p "$out/lua"
    cp -r ${./nvim/lua}/. "$out/lua/"
    chmod -R u+w "$out/lua"
    cp ${hostLua} "$out/lua/turbo/host.lua"
  '';

  runtimeDeps = [
    fd
    ripgrep

    bash-language-server
    basedpyright
    clang-tools
    dockerfile-language-server
    emmet-language-server
    gopls
    helm-ls
    lua-language-server
    nixd
    nixfmt # nixd shells out to this to format
    rust-analyzer
    terraform-ls
    typescript-language-server
    vscode-langservers-extracted # jsonls
    yaml-language-server
  ];

  plugins = with vimPlugins; [
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

    # Editing
    autoclose-nvim
    nvim-ts-autotag
    luasnip
    friendly-snippets

    # Completion
    nvim-cmp
    cmp-nvim-lsp
    cmp-buffer
    cmp-path
    cmp-cmdline
    cmp_luasnip

    # Finding
    plenary-nvim
    telescope-nvim
    telescope-fzf-native-nvim

    # LSP
    nvim-lspconfig
    fidget-nvim
  ];
in
wrapNeovim neovim-unwrapped {
  viAlias = true;
  vimAlias = true;

  # Pure Lua config, no remote plugins.
  withRuby = false;
  withPython3 = false;
  withNodeJs = false;

  # Suffix, not prefix: a project-local server on the caller's PATH still wins.
  extraMakeWrapperArgs = "--suffix PATH : ${lib.makeBinPath runtimeDeps}";

  configure = {
    customLuaRC = ''require("turbo")'';
    packages.turbo.start = plugins ++ [ runtime ];
  };
}
