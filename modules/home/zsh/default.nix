{ config, lib, pkgs, ... }:
let
  cfgZsh = config.modules.zsh;
in
{
  options.modules.zsh.enable = lib.mkEnableOption "Enable zsh shell";

  config = lib.mkIf cfgZsh.enable {
    programs.zsh = {
      enable = true;
      enableCompletion = true;

      syntaxHighlighting.enable = true;

      sessionVariables = {
        ZSH_DISABLE_COMPFIX = "true";

        ZVM_VI_ESCAPE_BINDKEY = "jk";

        EDITOR = "nvim";
        LESSOPEN = "| ${pkgs.highlight}/bin/highlight %s --out-format xterm256 --force";
      };

      zplug = {
        enable = true;
        plugins = [
          { name = "zsh-users/zsh-syntax-highlighting"; }
          { name = "zsh-users/zsh-autosuggestions"; }
          { name = "chrissicool/zsh-256color"; }
          { name = "zsh-users/zsh-completions"; }
        ];
      };

      shellAliases = {
        ls = "ls --color=auto";
        ll = "ls -l";
        la = "ls -la";
        history = "cat ~/.zsh_history";
        grep = "grep --color=auto";
        i = "swayimg";
        tree = "tree -C";
        sl = "sl -ea";
        lsusb = "cyme";
        til = "tea issues list --fields index,author,title";
      };

      # Use initContent ordering (keeps p10k instant prompt at the top)
      initContent = lib.mkMerge [
        (lib.mkOrder 500 ''
          # Powerlevel10k instant prompt (must be near the top)
          if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
            source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
          fi
        '')

        (lib.mkOrder 800 ''
          # History (portable: avoids programs.zsh.history option)
          HISTFILE="$HOME/.zsh_history"
          HISTSIZE=100000
          SAVEHIST=100000
          setopt APPEND_HISTORY
          setopt HIST_IGNORE_DUPS
          setopt HIST_SAVE_NO_DUPS
        '')

        (lib.mkOrder 1000 ''
          export PATH="$PATH:/usr/local/go/bin"
          export PATH="$PATH:$HOME/.local/bin"
          export PATH="$PATH:$HOME/go/bin"

          # Powerlevel10k theme from nixpkgs
          source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme

          # Load user p10k config if present
          [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
        '')
      ];
    };
  };
}
