{ pkgs, osConfig, ... }:
{
  home.username = "syscrypt";
  home.homeDirectory = "/home/syscrypt";
  home.stateVersion = "25.11";

  programs.git.enable = true;
  programs.gh.enable = true;

  home.packages = with pkgs; [ ripgrep ];
}
