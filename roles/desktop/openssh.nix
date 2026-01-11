{ pkgs, config, lib, services, ... }:
{
  config.sops.secrets.desktop_user_e_ed25519_pub_key = {
    path = "/etc/ssh/authorized_keys.d/evil_industries_ed25519.pub";
    mode = "0444";
  };

  config.services.openssh = {
    enable = false;

    openFirewall = true;

    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = true;
    };

    authorizedKeysFiles = [
      ".ssh/authorized_keys"
      "/etc/ssh/authorized_keys.d/%u"
    ];
  };
}
