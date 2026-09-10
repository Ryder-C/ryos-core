# Bundles. A host picks one (or none) and adds individual aspects on top.
{ry, ...}: {
  ry = with ry; {
    base.includes = [
      nix
      boot
      swap
      locale
      power
      networking
      mdns
      agenix
      gpg
      shell
      cli
      scripts
      yazi
      ghostty
      zellij
      editor
      git
    ];

    # niri + noctalia workstation.
    desktop.includes = [
      base
      fonts
      hardware
      audio
      bluetooth
      nix-ld
      input-remapper
      niri
      greetd
      noctalia
      catppuccin
      browser
      thunar
      wayland-tools
      apps
      dev
      ai
    ];

    server.includes = [
      base
      ssh
      no-sleep
    ];
  };
}
