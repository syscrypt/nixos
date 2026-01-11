{ pkgs, config, ... }:
{
  # TODO: Change later and set password
  users.mutableUsers = false;

  users.users.syscrypt = {
    isNormalUser = true;
    createHome = true;
    extraGroups = [ "wheel" "networkmanager" "docker" "power" "uucp" "dialout"];
    shell = pkgs.bashInteractive;
    hashedPasswordFile = config.sops.secrets.desktop_user_syscrypt_password.path;
  };

  systemd.tmpfiles.rules = [
    "d /home/syscrypt/.ssh 0700 syscrypt users -"
    "L+ /home/syscrypt/.ssh/evil_industries_ed25519 - - - - /run/secrets/desktop_user_e_ed25519_key"
    "L+ /home/syscrypt/.ssh/id_ed25519 - - - - /run/secrets/id_ed25519"
  ];
}
