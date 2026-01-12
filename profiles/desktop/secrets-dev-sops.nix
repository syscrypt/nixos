{ user, config, ... }:
let
  sFile = ../../secrets/desktop-profile-dev.yaml;
  homeDir = "/home/${user}";
in
{
  sops.age.keyFile = "/var/lib/sops-nix/vault.key";

  sops.secrets = {
    desktop_user_ed25519_1_key = {
      sopsFile = sFile;
      owner = user;
      mode = "0600";
      path = "${homeDir}/.ssh/id_ed25519";
    };

    desktop_user_e_ed25519_key = {
      sopsFile = sFile;
      owner = user;
      mode = "0600";
      path = "${homeDir}/.ssh/evil_industries_ed25519";
    };
  };

  systemd.tmpfiles.rules = [
    "d ${homeDir}/.ssh 0700 ${user} users -"
    "L+ ${homeDir}/.ssh/evil_industries_ed25519 - - - - /run/secrets/desktop_user_e_ed25519_key"
    "L+ ${homeDir}/.ssh/id_ed25519 - - - - /run/secrets/desktop_user_ed25519_1_key"
  ];
}
