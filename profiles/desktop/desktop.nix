# Base configuration file for all desktop environments

{ inputs, ... }:
{
  imports = [
    # Desktop stack
    inputs.disko.nixosModules.disko
    inputs.sops-nix.nixosModules.sops
    inputs.home-manager.nixosModules.home-manager

    ./openssh.nix
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    sharedModules = [
      inputs.self.homeManagerModules.default
    ];
  };
}
