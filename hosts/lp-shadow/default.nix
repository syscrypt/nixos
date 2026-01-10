{ inputs, ... }:
{
  networking.hostName = "laptop";

  imports = [
    ../../modules/nixos/base.nix
    ../../roles/users/syscrypt/user-syscrypt.nix
    ../../modules/nixos/secrets-sops.nix
    ./disko.nix
    ./hardware-configuration.nix
  ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.syscrypt = import ../../modules/home/syscrypt.nix;

  home-manager.extraSpecialArgs = { inherit inputs; };
}
