{ pkgs, config, ... }:
{
  _module.args.user = "syscrypt";

  imports = [
    ./secrets-sops.nix
  ];

  users = {
    mutableUsers = false;
    defaultUserShell = pkgs.zsh;

    users.syscrypt = {
      isNormalUser = true;
      createHome = true;
      extraGroups = [ "wheel" "networkmanager" "docker" "power" "uucp" "dialout"];
      shell = pkgs.bashInteractive;
      hashedPasswordFile = config.sops.secrets.user_password.path;
    };
  };

  home-manager.users.syscrypt = {
    imports = [
      ../default.nix
      ./home.nix
    ];
  };

}
