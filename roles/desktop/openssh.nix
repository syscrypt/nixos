{ pkgs, config, lib, services, ... }:
let
  cfg = config.features.openssh;
in
{
  options.features.openssh.enable =
    lib.mkEnableOption "OpenSSH server (sshd)";

  config = lib.mkIf cfg.enable {
    sops.secrets.desktop_user_e_ed25519_pub_key = {
      path = "/etc/ssh/authorized_keys.d/evil_industries_ed25519.pub";
      mode = "0444";
    };

    services.openssh = {
      enable = true;
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
  };
}
