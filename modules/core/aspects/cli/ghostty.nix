let
  rylib = import ../../_lib.nix;
in {
  ry.ghostty = {
    # ssh forwards $TERM but not terminfo. Ghostty's `ssh-terminfo` tics the
    # entry into the *login user's* ~/.terminfo on the remote, but sudo resets
    # HOME, so root's ncurses never finds it and anything with a pager
    # (`sudo journalctl`) dies with "'xterm-ghostty': unknown terminal type".
    # Installing the terminfo output system-wide puts it on TERMINFO_DIRS, which
    # NixOS' sudoers keeps for wheel, so it resolves for every user.
    nixos = {pkgs, ...}: {
      environment.systemPackages = [pkgs.ghostty.terminfo];
    };

    homeManager = {
      config,
      pkgs,
      ...
    }: {
      imports = [
        (rylib.whenNiri {
          programs.niri.settings.binds."Mod+Return".action.spawn = ["ghostty" "+new-window"];
        })
      ];

      programs.ghostty = {
        enable = true;
        settings = {
          background-opacity = 0.8;
          window-padding-x = 5;
          window-padding-y = 5;
          resize-overlay = "never";

          # Keep a warm instance so `ghostty +new-window` is instant instead of
          # paying Ghostty's ~0.5s cold start on every window.
          quit-after-last-window-closed = false;
          confirm-close-surface = false;

          font-family = "FiraCode Nerd Font";
          font-style = "Regular";

          clipboard-read = "allow";
          clipboard-write = "allow";

          # `ssh-terminfo` tics the xterm-ghostty entry over on first connect;
          # `ssh-env` falls back to xterm-256color if that fails.
          shell-integration-features = "ssh-env,ssh-terminfo";

          bell-features = "audio";
          bell-audio-path = "${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/window-attention.oga";
        };
      };

      # `ghostty +new-window` needs either a live instance or a D-Bus-activatable
      # name. dbus-broker only scans activation files at its own startup, so a
      # session bus older than the Ghostty install can never activate it and the
      # keybind silently does nothing. Start the daemon with the graphical
      # session instead; this is the symlink `systemctl --user enable` would write.
      xdg.configFile."systemd/user/graphical-session.target.wants/app-com.mitchellh.ghostty.service".source = "${config.programs.ghostty.package}/share/systemd/user/app-com.mitchellh.ghostty.service";
    };
  };
}
