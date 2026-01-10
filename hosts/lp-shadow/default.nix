{ inputs, ... }:
{
  networking.hostName = "lp-shadow";

  imports = [
    ../../modules/nixos/common.nix
    ../../modules/nixos/secrets-sops.nix
    ../../roles/desktop.nix
    ../../roles/users/syscrypt/user-syscrypt.nix
    ./disko.nix
    ./hardware-configuration.nix
  ];

  home-manager.users.syscrypt = import ../../modules/home/syscrypt.nix;
  home-manager.extraSpecialArgs = { inherit inputs; };
}
