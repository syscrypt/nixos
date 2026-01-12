{ inputs, ... }:
{
  imports = [
    inputs.home-manager.nixosModules.home-manager {
        home-manager.extraSpecialArgs = {inherit inputs;};
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.sharedModules = [
          inputs.self.homeManagerModules.default
        ];
    }

    ../../modules/nixos/common.nix
    ../../profiles/desktop/desktop.nix
    ../../users/syscrypt/default.nix
    ../../profiles/desktop/secrets-dev-sops.nix

    ./disko.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "lp-shadow";

  features.openssh.enable = false;
  modules.tmux.enable = true;
}
