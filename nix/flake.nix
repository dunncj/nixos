{
  description = "agartha - NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, home-manager, ... }:
    {
      nixosConfigurations.agartha = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

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

            # Without this the user config below is never evaluated. It was
            # missing, which left ./turbo/home.nix as dead code for months
            # while stale symlinks from an older run stayed in $HOME.
            home-manager.users.turbo = import ./turbo/home.nix;

            # Rename rather than fail when activation finds an unmanaged file
            # where it wants to write a symlink.
            home-manager.backupFileExtension = "hm-bak";
          }
        ];
      };
    };
}
