{
  # tuigreet lists whatever sessions the display-manager knows about and
  # remembers the last choice, so this works for niri, Plasma or both.
  ry.greetd.nixos = {
    config,
    lib,
    pkgs,
    ...
  }: {
    services.greetd = {
      enable = true;
      settings.default_session.command = lib.concatStringsSep " " ([
          (lib.getExe pkgs.tuigreet)
          "-r"
          "--time"
          "--sessions"
          "${config.services.displayManager.sessionData.desktops}/share/wayland-sessions"
        ]
        ++ lib.optionals config.programs.niri.enable ["--cmd" "niri-session"]);
    };

    services.gnome.gnome-keyring.enable = true;
    security.pam.services.greetd = {
      enableGnomeKeyring = true;
      enableKwallet = false;
    };
  };
}
