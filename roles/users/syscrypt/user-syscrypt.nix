{ pkgs, config, ... }:
{
  # TODO: Change later and set password
  users.mutableUsers = false;

  users.users.syscrypt = {
    isNormalUser = true;
    createHome = true;
    extraGroups = [ "wheel" "networkmanager" "docker" ];
    shell = pkgs.bashInteractive;
    hashedPasswordFile = config.sops.secrets.desktop_user_syscrypt_password.path;
  };

  systemd.tmpfiles.rules = [
    "d /home/syscrypt/.ssh 0700 syscrypt users -"
  ];
}
