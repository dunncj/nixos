{
  lib,
  runCommand,
  writeText,
  wrapNeovim,
  neovim-unwrapped,
  vimPlugins,

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

  flakePath ? null,
  hostName ? null,
}:

let
  hostLua = writeText "host.lua" ''
    return {
        flake = ${if flakePath == null then "nil" else ''"${flakePath}"''},
        hostname = ${if hostName == null then "nil" else ''"${hostName}"''},
    }
  '';

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
    nixfmt
    rust-analyzer
    terraform-ls
    typescript-language-server
    vscode-langservers-extracted
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

    autoclose-nvim
    nvim-ts-autotag
    luasnip
    friendly-snippets

    nvim-cmp
    cmp-nvim-lsp
    cmp-buffer
    cmp-path
    cmp-cmdline
    cmp_luasnip

    plenary-nvim
    telescope-nvim
    telescope-fzf-native-nvim

    nvim-lspconfig
    fidget-nvim
  ];
in
wrapNeovim neovim-unwrapped {
  viAlias = true;
  vimAlias = true;

  withRuby = false;
  withPython3 = false;
  withNodeJs = false;

  extraMakeWrapperArgs = "--suffix PATH : ${lib.makeBinPath runtimeDeps}";

  configure = {
    customLuaRC = ''require("turbo")'';
    packages.turbo.start = plugins ++ [ runtime ];
  };
}
