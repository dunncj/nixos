{
  description = "agartha - NixOS configuration, and turbo's portable environment";

  # No home-manager. The only thing it still did here was write dotfiles into
  # $HOME; those are now system programs writing /etc, which is inert for root
  # because root has none of the binaries that read them. See turbo/system.nix.
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      flakePath = "/home/turbo/nix";
      hostName = "agartha";
    in
    {
      # The portable unit. On another NixOS machine:
      #   imports = [ inputs.agartha.nixosModules.turbo ];
      # Nothing in it is specific to this host; set turbo.flakePath,
      # turbo.hostName and turbo.extraGroups there.
      nixosModules.turbo = ./turbo/system.nix;

      # turbo's environment as one derivation, for a machine that is not NixOS
      # at all:
      #   nix profile install github:dunncj/nixos?dir=nix#turbo
      # The editor carries its own config; the shell dotfiles do not travel
      # this way. See ./turbo/package.nix.
      packages.${system} = {
        turbo = import ./turbo/package.nix { inherit pkgs flakePath hostName; };
        neovim = pkgs.callPackage ./turbo/neovim.nix { inherit flakePath hostName; };
        default = self.packages.${system}.turbo;
      };

      nixosConfigurations.${hostName} = nixpkgs.lib.nixosSystem {
        inherit system;

        modules = [
          # hardware-configuration.nix is imported by configuration.nix, so it
          # is deliberately not listed again here.
          ./hosts/agartha/configuration.nix

          ./modules/rebuild.nix
          ./modules/k3s.nix
          ./modules/sunshine.nix
          ./modules/power.nix

          self.nixosModules.turbo
          {
            turbo = {
              inherit flakePath hostName;
              extraGroups = [ "docker" ];
            };
          }
        ];
      };
    };
}
