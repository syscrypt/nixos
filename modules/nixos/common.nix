{ pkgs, ... }:
{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  time.timeZone = "Europe/Berlin";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.editor = false;

  networking.networkmanager.enable = true;

  environment.systemPackages = with pkgs; [
    git
    vim
    openssh
    curl
    wget
  ];

  system.stateVersion = "25.11";

  i18n.defaultLocale = "en_US.UTF-8";

  console.keyMap = "de";
}
