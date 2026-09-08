# The CLI tools turbo expects on any machine. Shared by ./home.nix and
# ./package.nix so the module and the environment package cannot drift apart.
#
# The editor is not here - it is ./neovim.nix, which is a wrapper around a lot
# more than a package name.
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
  starship
  tree
]
