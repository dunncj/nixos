{
  description = "agartha - NixOS configuration, and turbo's portable environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      flakePath = "/home/turbo/nix";
      hostName = "agartha";
    in
    {
      # The portable unit. On another machine:
      #   home-manager.users.turbo = inputs.agartha.homeModules.turbo;
      # Nothing in it is specific to this host; set turbo.flakePath and
      # turbo.hostName there if that machine is also built from a flake.
      homeModules.turbo = ./turbo/home.nix;

      # turbo's environment as one derivation, for a machine that has nix but
      # no home-manager - or no NixOS at all:
      #   nix profile install github:dunncj/nixos?dir=nix#turbo
      # The editor carries its own config; the shell dotfiles do not travel
      # this way. See ./turbo/package.nix.
      packages.${system} = {
        turbo = import ./turbo/package.nix { inherit pkgs flakePath hostName; };
        neovim = pkgs.callPackage ./turbo/neovim.nix { inherit flakePath hostName; };
        default = self.packages.${system}.turbo;
      };

      # Standalone home-manager, for a Linux box that is not NixOS:
      #   home-manager switch --flake .#turbo
      homeConfigurations.turbo = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ self.homeModules.turbo ];
      };

      nixosConfigurations.${hostName} = nixpkgs.lib.nixosSystem {
        inherit system;

        modules = [
          # hardware-configuration.nix is imported by configuration.nix, so it
          # is deliberately not listed again here.
          ./hosts/agartha/configuration.nix

          ./modules/rebuild.nix
          ./modules/turbo.nix
          ./modules/k3s.nix
          ./modules/sunshine.nix
          ./modules/power.nix

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;

            home-manager.users.turbo = {
              imports = [ self.homeModules.turbo ];

              # Point nixd at this flake for option completion.
              turbo = { inherit flakePath hostName; };
            };

            # Rename rather than fail when activation finds an unmanaged file
            # where it wants to write a symlink.
            home-manager.backupFileExtension = "hm-bak";
          }
        ];
      };
    };
}
