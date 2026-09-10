{inputs, ...}: let
  rylib = import ../../../_lib.nix;
in {
  flake-file.inputs.niri.url = "github:sodiboo/niri-flake";

  ry.niri = {
    includes = [(rylib.groups ["seat"])];

    nixos = {
      lib,
      pkgs,
      ...
    }: {
      programs.niri.enable = true;
      services = {
        displayManager.defaultSession = lib.mkForce "niri";
        libinput.enable = true;
        seatd.enable = true;
      };
      security.polkit.enable = true;
      programs.dconf.enable = true;
      xdg.portal = {
        enable = true;
        wlr.enable = true;
        xdgOpenUsePortal = true;
        extraPortals = [pkgs.xdg-desktop-portal-gtk];
      };

      # xdgOpenUsePortal makes the portal resolve and launch default handlers
      # itself. GLib drops any desktop entry whose Exec argv[0] isn't on PATH,
      # and these units only inherit systemd's minimal environment, so apps
      # with a bare Exec (helium, tor-browser) vanished and links fell through
      # to the next browser. Give the portal the session PATH.
      systemd.user.services = let
        sessionPath = {
          overrideStrategy = "asDropin";
          serviceConfig.Environment = [
            ("PATH="
              + builtins.concatStringsSep ":" [
                "/run/wrappers/bin"
                "%h/.nix-profile/bin"
                "/nix/profile/bin"
                "%h/.local/state/nix/profile/bin"
                "/etc/profiles/per-user/%u/bin"
                "/nix/var/nix/profiles/default/bin"
                "/run/current-system/sw/bin"
              ])
          ];
        };
      in {
        xdg-desktop-portal = sessionPath;
        xdg-desktop-portal-gtk = sessionPath;
        xdg-desktop-portal-gnome = sessionPath;
        # noctalia provides the polkit agent.
        niri-flake-polkit.enable = false;
      };

      environment.systemPackages = [pkgs.xwayland];
    };

    homeManager = {
      lib,
      pkgs,
      ...
    }: {
      imports = [
        inputs.niri.homeModules.niri
        ./_window-rules.nix
      ];

      home.packages = [pkgs.xwayland-satellite];

      xdg.portal = {
        enable = true;
        extraPortals = [pkgs.xdg-desktop-portal-gnome pkgs.xdg-desktop-portal-gtk];
        # niri implements screencast via org.gnome.Mutter.ScreenCast, so it
        # must go to xdp-gnome. xdp-wlr's screencopy path has no damage
        # tracking here, which niri treats as a one-off screenshot -- the
        # screenshare freezes on its first frame.
        config.niri = {
          default = ["gtk"];
          "org.freedesktop.impl.portal.ScreenCast" = ["gnome"];
          "org.freedesktop.impl.portal.Screenshot" = ["gnome"];
        };
      };

      home.sessionVariables = {
        NIXOS_OZONE_WL = "1";
        __GL_GSYNC_ALLOWED = "1";
        __GL_VRR_ALLOWED = "1";
        DISABLE_QT5_COMPAT = "0";
        GDK_BACKEND = "wayland";
        ANKI_WAYLAND = "1";
        QT_AUTO_SCREEN_SCALE_FACTOR = "1";
        QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
        # Semicolon list: apps bundling a Qt without a wayland plugin (eg DaVinci
        # Resolve ships Qt 5.15.2 with only xcb) fall back instead of aborting.
        QT_QPA_PLATFORM = "wayland;xcb";
        MOZ_ENABLE_WAYLAND = "1";
      };

      programs.niri = {
        enable = true;
        package = lib.mkForce pkgs.niri;
        settings = {
          prefer-no-csd = true;
          hotkey-overlay.skip-at-startup = true;

          input = {
            mouse.accel-profile = "flat";
            keyboard.xkb = {
              layout = "us,fr";
              options = "grp:alt_caps_toggle";
            };
            touchpad = {
              tap = false;
              natural-scroll = true;
              scroll-factor = 0.5;
            };
            warp-mouse-to-focus.enable = false;
            focus-follows-mouse.enable = true;
            workspace-auto-back-and-forth = true;
          };

          layout = {
            gaps = 4;
            center-focused-column = "never";
            preset-column-widths = [
              {proportion = 0.33333;}
              {proportion = 0.5;}
              {proportion = 0.66667;}
            ];
            default-column-width.proportion = 0.5;
            border = {
              enable = true;
              width = 2;
              active.color = "#cba6f7";
              inactive.color = "#45475a";
            };
            focus-ring.enable = false;
            tab-indicator.place-within-column = true;
          };

          spawn-at-startup = [
            {command = ["systemctl" "--user" "import-environment"];}
          ];

          binds = let
            workspaces = lib.range 1 9;
            focusWs = builtins.listToAttrs (map (n: lib.nameValuePair "Mod+${toString n}" {action.focus-workspace = n;}) workspaces);
            moveWs = builtins.listToAttrs (map (n: lib.nameValuePair "Mod+Shift+${toString n}" {action.move-column-to-workspace = n;}) workspaces);
          in
            focusWs
            // moveWs
            // {
              "Mod+Shift+Slash".action.show-hotkey-overlay = {};
              "Mod+Q".action.close-window = {};
              "Mod+C".action.center-column = {};

              # Colemak focus
              "Mod+m".action.focus-column-or-monitor-left = {};
              "Mod+n".action.focus-window-or-workspace-down = {};
              "Mod+e".action.focus-window-or-workspace-up = {};
              "Mod+i".action.focus-column-or-monitor-right = {};

              # Colemak move
              "Mod+Shift+m".action.move-column-left-or-to-monitor-left = {};
              "Mod+Shift+n".action.move-window-down-or-to-workspace-down = {};
              "Mod+Shift+e".action.move-window-up-or-to-workspace-up = {};
              "Mod+Shift+i".action.move-column-right-or-to-monitor-right = {};

              # Colemak consume/expel
              "Mod+Ctrl+m".action.consume-or-expel-window-left = {};
              "Mod+Ctrl+i".action.consume-or-expel-window-right = {};

              # Monitors
              "Mod+Left".action.focus-monitor-left = {};
              "Mod+Right".action.focus-monitor-right = {};
              "Mod+Shift+Left".action.spawn = ["sh" "-c" "niri msg action move-window-to-monitor-left && niri msg action move-column-to-first"];
              "Mod+Shift+Right".action.spawn = ["sh" "-c" "niri msg action move-window-to-monitor-right && niri msg action move-column-to-first"];

              # Workspaces
              "Mod+Up".action.focus-workspace-up = {};
              "Mod+Down".action.focus-workspace-down = {};
              "Mod+O".action.toggle-overview = {};
              "Mod+W".action.toggle-column-tabbed-display = {};

              "Mod+F".action.maximize-column = {};
              "Mod+Ctrl+F".action.expand-column-to-available-width = {};
              "Mod+Shift+F".action.fullscreen-window = {};
              "Mod+Shift+Space".action.toggle-window-floating = {};

              "Mod+BracketLeft".action.consume-window-into-column = {};
              "Mod+BracketRight".action.expel-window-from-column = {};

              "Mod+Shift+Q".action.quit.skip-confirmation = true;

              # Media keys
              "XF86AudioPlay".action.spawn = ["playerctl" "play-pause"];
              "XF86AudioNext".action.spawn = ["playerctl" "next"];
              "XF86AudioPrev".action.spawn = ["playerctl" "previous"];

              # Brightness keys; noctalia shows the OSD on its own.
              "XF86MonBrightnessUp" = {
                allow-when-locked = true;
                action.spawn = ["brightnessctl" "set" "5%+"];
              };
              "XF86MonBrightnessDown" = {
                allow-when-locked = true;
                action.spawn = ["brightnessctl" "set" "5%-"];
              };

              # Mission Control key (Mac F3) opens the overview.
              "XF86LaunchA".action.toggle-overview = {};

              # Screenshots
              "Mod+S".action.screenshot = {};
              "Mod+Shift+S".action.screenshot-screen = {};
              "Mod+Alt+S".action.screenshot-window = {};
            };
        };
      };
    };
  };
}
