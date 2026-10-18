{
  programs.umbriel.settings.window_rule = [
    {
      match.app_id = ["^code$" "^antigravity$"];
      default_maximize = true;
    }
    {
      match.app_id = "^dev[.]noctalia[.]Noctalia$";
      default_floating = true;
      default_floating_size_px = {
        width = 1020;
        height = 900;
      };
    }
    {
      match.app_id = "^dev[.]noctalia[.]UmbrielSharePicker$";
      default_floating = true;
      default_floating_size_px = {
        width = 800;
        height = 600;
      };
    }
    {
      match.title = "^(Picture-in-Picture|Picture in picture)$";
      default_floating = true;
      default_maximize = false;
      default_position = {
        x = 20;
        y = 20;
        anchor = "bottom_right";
      };
    }
    {
      match.app_id = [
        "^.blueman-manager-wrapped$"
        "^[Ww]aydroid"
        "^org.gnome.Nautilus$"
        "^ninjabrainbot"
        "^com[.]gabm[.]satty$"
      ];
      default_floating = true;
    }
    {
      match.app_id = "^thunar$";
      match.title = ["^Rename" "^File Operation Progress$"];
      default_floating = true;
    }
    {
      # Keep the pointer inside games while they're focused; menus that drop
      # their pointer lock otherwise let it slide onto the other monitor.
      match.app_id = "^steam_app_";
      confine_pointer = true;
    }
  ];
}
