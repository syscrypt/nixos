{ pkgs, ... }:
{
  # TODO: Change later and set password
  users.mutableUsers = true;

  users.users.syscrypt = {
    isNormalUser = true;
    createHome = true;
    extraGroups = [ "wheel" "networkmanager" "docker" ];
    shell = pkgs.bashInteractive;
    # Optional: set a password hash (recommended for immutable users):
    # hashedPassword = "…";
  };

  systemd.tmpfiles.rules = [
    "d /home/syscrypt/.ssh 0700 syscrypt users -"
  ];
}
