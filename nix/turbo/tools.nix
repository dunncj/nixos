# The CLI tools turbo expects on any machine. Shared by ./home.nix and
# ./package.nix so the module and the environment package cannot drift apart.
#
# Anything with config of its own is not here: the editor is ./neovim.nix and
# git/tmux/starship are ./wrappers.nix, each carrying its config inside the
# derivation.
#
# direnv is here rather than wrapped because its config is a shell hook, which
# ./system.nix installs into zsh.
pkgs: with pkgs; [
  bat
  direnv
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
]
