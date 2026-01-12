{ config, lib, pkgs, ... }:
let
  cfgTmux = config.modules.tmux;
in {
  options.modules.tmux.enable = lib.mkEnableOption "Enable tmux";

  config = lib.mkIf cfgTmux.enable {
    programs.tmux = {
      enable = true;
      clock24 = true;
      newSession = true;
      keyMode = "vi";
      plugins = with pkgs.tmuxPlugins; [ nord ];

      extraConfig = ''
        # enable mouse
        set -g mouse on

        # rebind split
        bind | split-window -h -c "#{pane_current_path}"
        bind - split-window -v -c "#{pane_current_path}"

        # switch with Alt
        bind -n M-h select-pane -L
        bind -n M-l select-pane -R
        bind -n M-k select-pane -U
        bind -n M-j select-pane -D

        set -g @plugin "nordtheme/tmux"
      '';
    };
  };
}
