{ config, lib, ... }:
let
  syscryptDepl = lib.mkIf config.users.users ? syscrypt {
    systemd.tmpfiles.rules = [
      "d /home/syscrypt/.ssh 0700 syscrypt users -"
    ];

    sops.secrets.syscrypt_ssh_ed25519 = {
      owner = "syscrypt";
      mode = "0600";
      path = "/home/syscrypt/.ssh/id_ed25519";
    };
  };
in
{
  sops.defaultSopsFormat = "yaml";
  sops.age.keyFile = "vault/vault.key";
}
