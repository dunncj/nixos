{
  description = "Nixos config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };
  
  outputs = inputs@{ self, nixpkgs, home-manager, ... }: 
  let
    system = "x86_64-linux";
	  pkgs = 
      import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      mkComputer = configurationNix: userName: emodules: ehomeModules: inputs.nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs system; };
        modules = [
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users."${userName}" = {
              imports = [ (./. + "/users/${userName}/home.nix") ] ++ ehomeModules;
            };
          }
          configurationNix
        ] ++ emodules;
      };


  in 
  {
	  nixosConfigurations =  {
		  titan = mkComputer 
        ./hosts/titan/configuration.nix
        "turbo"
        [
          ./sys-modules/utils/utils.nix
          ./sys-modules/dev-tools/dev-tools.nix
          ./sys-modules/desktop/desktop.nix
          ./sys-modules/steam/steam.nix
        ]
        [
          ./home-modules/sway/sway.nix
          ./home-modules/wofi/wofi.nix
          ./home-modules/scripts/build.nix
          ./home-modules/scripts/steam.nix
          ./home-modules/zellij/zellij.nix
          ./home-modules/communication/communication.nix
          ./home-modules/dev-tools/dev-tools.nix
          ./home-modules/browsers/chrome.nix
          ./home-modules/browsers/firefox.nix
          ./home-modules/gaming/steam.nix
          ./home-modules/gaming/minecraft.nix
          ./home-modules/desktop/desktop.nix
          ./home-modules/desktop-apps/desktop-apps.nix
        ];
      };
  };
}
