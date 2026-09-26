{
  # Everyday command-line tools; nothing here needs a display.
  ry.cli.homeManager = {pkgs, ...}: {
    home.packages = with pkgs; [
      bandwhich
      bitwise
      dua
      entr
      eza
      fd
      file
      fzf
      gdu
      gtrash
      hexdump
      jq
      killall
      man-pages
      nix-prefetch-github
      nix-search-cli
      openssl
      ripgrep
      unrar
      unzip
      websocat
      wget
      xxd
    ];

    programs = {
      bat = {
        enable = true;
        config.pager = "less -FR";
      };
      btop = {
        enable = true;
        settings = {
          theme_background = false;
          update_ms = 500;
          # btop otherwise rewrites btop.conf on exit, replacing the HM symlink
          # and breaking activation ("would be clobbered").
          save_config_on_exit = false;
        };
      };
    };

    xdg.configFile."btop/btop.conf".force = true;

    home.shellAliases = {
      cat = "bat";
      tt = "gtrash put";
    };
  };
}
