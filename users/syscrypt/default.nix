{ ... }:
{
  _module.args.user = "syscrypt";

  imports = [
    ./secrets-sops.nix
    ./user.nix
  ];

  home-manager.users.syscrypt = {
    imports = [
      ../default.nix
      ./home.nix
    ];
  };
}
