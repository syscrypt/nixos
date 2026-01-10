# Base configuration file for all desktop environments

{ inputs, ... }:
{
  imports = [
    # Desktop stack
    inputs.sops-nix.nixosModules.sops
    inputs.home-manager.nixosModules.home-manager

    # Shared system modules
    ../modules/nixos/base.nix
  ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.extraSpecialArgs = { inherit inputs; };
}
