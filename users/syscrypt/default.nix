{ inputs, ... }:
{
  _module.args.user = "syscrypt";

  imports = [
    ./secrets-sops.nix
    ./user.nix
  ];

  home-manager.users.syscrypt = import ./home.nix;
  home-manager.extraSpecialArgs = { inherit inputs; };
}
