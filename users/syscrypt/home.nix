{ pkgs, ... }:
{
  home = {
    username = "syscrypt";
    homeDirectory = "/home/syscrypt";
    stateVersion = "25.11";
    packages = [ pkgs.ripgrep ];
  };
}
