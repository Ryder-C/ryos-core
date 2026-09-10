{
  ry.fonts = {
    nixos = {pkgs, ...}: {
      fonts.packages = with pkgs; [
        nerd-fonts.fira-code
        noto-fonts
        noto-fonts-color-emoji
      ];
    };

    homeManager = {pkgs, ...}: {
      home.packages = with pkgs; [
        nerd-fonts.fira-code
        nerd-fonts.noto
        twemoji-color-font
        noto-fonts-color-emoji
      ];
      fonts.fontconfig = {
        enable = true;
        defaultFonts.monospace = ["FiraCode Nerd Font" "Noto Color Emoji"];
      };
    };
  };
}
