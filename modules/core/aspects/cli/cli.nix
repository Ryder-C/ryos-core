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
        };
      };
    };

    home.shellAliases = {
      cat = "bat";
      tt = "gtrash put";
    };
  };
}
