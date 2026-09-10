{inputs, ...}: {
  flake-file.inputs = {
    flatpaks.url = "github:in-a-dil-emma/declarative-flatpak";
    hytale-flatpak = {
      url = "https://launcher.hytale.com/builds/release/linux/amd64/hytale-launcher-latest.flatpak";
      flake = false;
    };
    jellium-flatpak = {
      url = "https://nightly.link/andrewrabert/jellium-desktop/workflows/build-linux-flatpak/main/linux-flatpak-x86_64.zip";
      flake = false;
    };
  };

  # `ry.flatpak` = flatpak + flathub + Flatseal. Apps are opt-in:
  # ry.flatpak.{sober,plex,hytale,jellium}.
  ry.flatpak = {
    nixos.services.flatpak.enable = true;

    homeManager = {pkgs, ...}: {
      imports = [inputs.flatpaks.homeModules.default];
      home.packages = [pkgs.flatpak];
      services.flatpak = {
        enable = true;
        remotes.flathub = "https://dl.flathub.org/repo/flathub.flatpakrepo";
        packages = ["flathub:app/com.github.tchx84.Flatseal/x86_64/stable"];
      };
    };

    provides = {
      sober.homeManager = {config, ...}: {
        services.flatpak.packages = ["flathub:app/org.vinegarhq.Sober/x86_64/stable"];
        # Expose the flatpak's icon to the launcher.
        xdg.dataFile."icons/hicolor/scalable/apps/org.vinegarhq.Sober.svg".source =
          config.lib.file.mkOutOfStoreSymlink "${config.xdg.dataHome}/flatpak/exports/share/icons/hicolor/scalable/apps/org.vinegarhq.Sober.svg";
      };

      plex.homeManager.services.flatpak = {
        packages = ["flathub:app/tv.plex.PlexDesktop/x86_64/stable"];
        overrides."tv.plex.PlexDesktop".Environment.QT_QPA_PLATFORM = "xcb";
      };

      hytale.homeManager = {pkgs, ...}: {
        services.flatpak.packages = [
          ":${pkgs.runCommand "hytale-launcher.flatpak" {} "ln -s ${inputs.hytale-flatpak} $out"}"
        ];
      };

      jellium.homeManager = {pkgs, ...}: {
        services.flatpak = {
          packages = [
            ":${pkgs.runCommand "jellium-desktop.flatpak" {} "ln -s ${inputs.jellium-flatpak} $out"}"
          ];
          overrides."net.nullsum.JelliumDesktop"."System Bus Policy" = {
            "org.freedesktop.login1" = "talk";
          };
        };
      };
    };
  };
}
