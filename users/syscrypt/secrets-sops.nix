{ config, lib, ... }:
{
  sops.age.keyFile = "/var/lib/sops-nix/vault.key";

  sops.secrets = {
    user_password = {
      sopsFile = ../../secrets/desktop-user-syscrypt.yaml;
      key = "user_password";
      neededForUsers = true;
      owner = "root";
      mode = "0400";
    };
  };

  users.users.syscrypt.hashedPasswordFile =
    config.sops.secrets.user_password.path;
}
