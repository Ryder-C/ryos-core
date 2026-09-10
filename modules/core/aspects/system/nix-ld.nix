{
  # Run unpatched dynamic binaries (AppImages, vendor blobs, pip wheels).
  ry.nix-ld.nixos = {pkgs, ...}: {
    programs.nix-ld = {
      enable = true;
      libraries = with pkgs; [
        gtk3
        glib
        gdk-pixbuf
        pango
        harfbuzz
        atk
        cairo
        libepoxy
        mpv
        keybinder3
        gsettings-desktop-schemas
        zlib
        alsa-lib
        fontconfig
        freetype
        libxkbcommon
        libdrm
        libxcb
        wayland
        libx11
        libxext
        libxrender
        libxfixes
        libxinerama
        libxi
        libxrandr
        libxscrnsaver
        libxtst
        libxcb-util
        libxcb-image
        libxcb-render-util
        libxcb-wm
        libxcb-keysyms
        libva
      ];
    };
  };
}
