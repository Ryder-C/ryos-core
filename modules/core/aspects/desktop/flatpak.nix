{inputs, ...}: {
  flake-file.inputs = {
    flatpaks.url = "github:in-a-dil-emma/declarative-flatpak";
    hytale-flatpak = {
      url = "https://launcher.hytale.com/builds/release/linux/amd64/hytale-launcher-latest.flatpak";
      flake = false;
    };
  };

  # `ry.flatpak` = flatpak + flathub + Flatseal. Apps are opt-in:
  # ry.flatpak.{sober,plex,hytale}.
  ry.flatpak = {
    nixos.services.flatpak.enable = true;

    homeManager = {pkgs, ...}: {
      imports = [inputs.flatpaks.homeModules.default];
      home.packages = [pkgs.flatpak];
      services.flatpak = {
        enable = true;
        remotes.flathub = "https://dl.flathub.org/repo/flathub.flatpakrepo";
        packages = ["flathub:app/com.github.tchx84.Flatseal/x86_64/stable"];
        # Sync from the graphical session (the v4.2 default; set explicitly
        # to silence its trace).
        runWithoutGui = false;
      };

      # The activation sync is a oneshot WantedBy graphical-session.target,
      # and a target waits for every oneshot it pulls in to finish. Whenever
      # the flatpak config changed, the whole session (portal, ghostty's
      # D-Bus service, everything After the target) sat behind a minute-long
      # download. DefaultDependencies=no drops that implicit After=; the rest
      # of what it normally adds is restored by hand. Still a oneshot, so
      # manage-flatpaks-auto keeps waiting for it.
      systemd.user.services.manage-flatpaks-activation.Unit = {
        DefaultDependencies = false;
        After = ["basic.target"];
        Conflicts = ["shutdown.target"];
        Before = ["shutdown.target"];
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
    };
  };
}
