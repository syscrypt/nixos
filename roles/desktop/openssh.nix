{ pkgs, config, lib, services, ... }:
let
  cfg = config.features.openssh;
in
{
  options.features.openssh.enable =
    lib.mkEnableOption "OpenSSH server (sshd)";

  config = lib.mkIf cfg.enable {
    sops.secrets.desktop_authorized_keys = {
      path = "/etc/ssh/authorized_keys.d/authorized_keys";
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
        "%h/.ssh/authorized_keys"
        "/etc/ssh/authorized_keys.d/authorized_keys"
      ];
    };
  };
}
