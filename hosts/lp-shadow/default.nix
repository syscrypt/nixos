{ inputs, ... }:
{
  networking.hostName = "lp-shadow";

  imports = [
    inputs.home-manager.nixosModules.home-manager

    ../../modules/nixos/common.nix
    ../../profiles/desktop/desktop.nix
    ../../users/syscrypt/default.nix
    ../../profiles/desktop/secrets-dev-sops.nix

    ./disko.nix
    ./hardware-configuration.nix
  ];

  features.openssh.enable = false;
}
