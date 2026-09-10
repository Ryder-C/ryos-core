{
  programs.niri.settings = {
    window-rules = [
      {
        # Round corners for all windows.
        geometry-corner-radius = {
          top-left = 10.0;
          top-right = 10.0;
          bottom-left = 10.0;
          bottom-right = 10.0;
        };
        clip-to-geometry = true;
      }
      {
        matches = [{app-id = "^com\\.mitchellh\\.ghostty$";}];
        focus-ring.enable = false;
      }
      {
        matches = [
          {app-id = "^code$";}
          {app-id = "^antigravity$";}
        ];
        open-maximized = true;
      }
      {
        # Indicate screencasted windows with red colors.
        matches = [{is-window-cast-target = true;}];
        focus-ring = {
          active.color = "#f38ba8";
          inactive.color = "#7d0d2d";
        };
        border.inactive.color = "#7d0d2d";
        shadow.color = "#7d0d2d70";
        tab-indicator = {
          active.color = "#f38ba8";
          inactive.color = "#7d0d2d";
        };
      }
      {
        matches = [
          {app-id = "^.blueman-manager-wrapped$";}
          {app-id = "^[Ww]aydroid";}
          {app-id = "^org.gnome.Nautilus$";}
          {app-id = "^ninjabrainbot";}
          {app-id = "^com\\.gabm\\.satty$";}
          {
            app-id = "^thunar$";
            title = "^Rename";
          }
          {
            app-id = "^thunar$";
            title = "^File Operation Progress$";
          }
        ];
        open-floating = true;
      }
    ];
  };
}
