{ pkgs, config, ... }:
{
  users.mutableUsers = false;

  users.users.syscrypt = {
    isNormalUser = true;
    createHome = true;
    extraGroups = [ "wheel" "networkmanager" "docker" "power" "uucp" "dialout"];
    shell = pkgs.bashInteractive;
    hashedPasswordFile = config.sops.secrets.user_password.path;
  };
}
