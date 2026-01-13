{ ... }:
{
  imports = [
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
  modules.zsh.enable = true;
}
