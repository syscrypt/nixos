{ config, ... }:
{
  sops.defaultSopsFormat = "yaml";
  sops.defaultSopsFile = ../../secrets.yaml;
  sops.age.keyFile = "/var/lib/sops-nix/vault.key";

  sops.secrets.desktop_user_syscrypt_password = {
    owner = "root";
    mode = "0400";
    neededForUsers = true;
  };

  sops.secrets.desktop_user_ed25519_1_key = {
    owner = "syscrypt";
    mode = "0600";
    path = "/home/syscrypt/.ssh/id_ed25519";
  };

  sops.secrets.desktop_user_e_ed25519_key = {
    owner = "syscrypt";
    mode = "0600";
    path = "/home/syscrypt/.ssh/evil_industries_ed25519";
  };
}
