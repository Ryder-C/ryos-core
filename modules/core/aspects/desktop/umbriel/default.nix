{
  inputs,
  ry,
  ...
}: let
  rylib = import ../../../_lib.nix;
in {
  # Binary cache only: the `cachix` branch trails main to the newest commit
  # CI has pushed, and overriding any input (nixpkgs.follows included)
  # changes the hash and misses the cache.
  flake-file.inputs.umbriel.url = "github:noctalia-dev/umbriel/cachix";

  ry.umbriel = {
    includes = [(rylib.groups ["seat"]) ry.wayscriber];

    nixos = {
      lib,
      pkgs,
      ...
    }: {
      # Brings xdg-desktop-portal-umbriel (ScreenCast + Screenshot) along and
      # writes umbriel-portals.conf (umbriel first, gtk for the rest).
      imports = [inputs.umbriel.nixosModules.default];

      nix.settings = {
        substituters = ["https://umbriel.cachix.org"];
        trusted-public-keys = ["umbriel.cachix.org-1:JfNq/2yg2S6D6z4Z2dVSZrZlDPQTKtexB6GAVLD98nw="];
      };

      programs.umbriel.enable = true;
      services = {
        displayManager.defaultSession = lib.mkForce "umbriel";
        libinput.enable = true;
        seatd.enable = true;
      };
      security.polkit.enable = true;
      programs.dconf.enable = true;
      xdg.portal = {
        enable = true;
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
      };
    };

    homeManager = {
      config,
      lib,
      pkgs,
      ...
    }: let
      cfg = config.programs.umbriel;

      # hdr = "auto" can't help browsers or mpv-based players: an output in
      # SDR is described to clients as SDR, so they never ask for HDR content
      # and nothing ever triggers the switch. config-hdr.toml is the same
      # config with every "auto" output forced on; Mod+Shift+H swaps between
      # the two for the session (config-replace doesn't survive a restart, so
      # every login starts on auto).
      hdrForced =
        cfg.settings
        // {
          output =
            lib.mapAttrs (_: o:
              if (o.hdr or null) == "auto"
              then o // {hdr = "on";}
              else o) (cfg.settings.output or {});
        };
      hdrToggle = pkgs.writeShellApplication {
        name = "umbriel-hdr-toggle";
        runtimeInputs = [cfg.package pkgs.jq pkgs.libnotify];
        text = ''
          dir="''${XDG_CONFIG_HOME:-$HOME/.config}/umbriel"
          if umbriel color --json | jq -e '[.outputs[].hdr_mode] | index("on")' >/dev/null; then
            umbriel config-replace "$dir/config.toml"
            notify-send -a Umbriel -i video-display "HDR auto" "HDR only for fullscreen HDR content"
          else
            umbriel config-replace "$dir/config-hdr.toml"
            notify-send -a Umbriel -i video-display "HDR on" "Mod+Shift+H to go back to auto"
          fi
        '';
      };
    in {
      xdg.configFile."umbriel/config-hdr.toml".source =
        (pkgs.formats.toml {}).generate "umbriel-config-hdr.toml" hdrForced;

      imports = [
        inputs.umbriel.homeModules.default
        ./_window-rules.nix
      ];

      # start-umbriel re-enters the login shell, which sources these, and
      # imports the result into the systemd user manager.
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

        # hdr = "auto" only switches an output to HDR for fullscreen content
        # that tags itself as HDR, and XWayland content can't. Run Proton
        # through Wine's Wayland driver so DXVK/vkd3d publish HDR metadata.
        # GE and cachyos spell the switch differently; set both. A game that
        # breaks under Wine-Wayland can opt out with
        # `PROTON_ENABLE_WAYLAND=0 %command%`.
        PROTON_ENABLE_WAYLAND = "1";
        PROTON_ENABLE_HDR = "1";
        DXVK_HDR = "1";
      };

      programs.umbriel = {
        enable = true;
        settings = {
          general.show_cheatsheet = false;

          input = {
            mouse.accel_profile = "flat";
            keyboard = {
              layout = "us,fr";
              options = "grp:alt_caps_toggle";
            };
            touchpad = {
              tap = false;
              natural_scroll = true;
              scroll_factor = 0.5;
            };
            focus.follows_mouse = true;
          };

          workspaces.back_and_forth = true;

          layout = {
            gap = 4;
            extent_presets = [0.33333 0.5 0.66667];
            scrolling = {
              default_extent_fraction = 0.5;
              center_focused = "never";
            };
          };

          appearance = {
            prefer_no_csd = true;
            border_width = 2;
            corner_radius = 10;
          };

          # Catppuccin Mocha: mauve / surface1.
          colors.border = {
            focused = "#cba6f7ff";
            unfocused = "#45475aff";
          };

          hot_corners.top_left = {
            enabled = true;
            delay_ms = 150;
            action = "overview-open";
          };

          keybinds = let
            once = action: {
              inherit action;
              repeat = false;
            };
            whenLocked = action: {
              inherit action;
              allow_when_locked = true;
            };
            workspaces = lib.range 1 9;
            perWorkspace = key: action:
              builtins.listToAttrs (map (n: lib.nameValuePair "${key}${toString n}" "${action}:${toString n}") workspaces);
            # Moving a window across outputs lands it wherever the target's
            # strip is scrolled; pull its column to the front so it's in view.
            toOutput = dir: "spawn:umbriel msg window-move-to-output-${dir} && umbriel msg column-move-to-first";
          in
            perWorkspace "Mod+" "workspace-switch"
            // perWorkspace "Mod+Shift+" "column-move-to-workspace"
            // {
              "Mod+Shift+Slash" = once "cheatsheet-toggle";
              "Mod+Q" = once "window-close";
              "Mod+Ctrl+Q" = once "window-kill";
              "Mod+C" = "column-center";

              # Colemak focus
              "Mod+M" = "window-focus-or-output-left";
              "Mod+N" = "window-focus-or-workspace-down";
              "Mod+E" = "window-focus-or-workspace-up";
              "Mod+I" = "window-focus-or-output-right";

              # Colemak move
              "Mod+Shift+M" = "window-move-or-output-left";
              "Mod+Shift+N" = "window-move-or-workspace-down";
              "Mod+Shift+E" = "window-move-or-workspace-up";
              "Mod+Shift+I" = "window-move-or-output-right";

              # Colemak consume/expel
              "Mod+Ctrl+M" = "window-consume-or-expel-left";
              "Mod+Ctrl+I" = "window-consume-or-expel-right";

              # Tabs (Mod+W tabs the column)
              "Mod+Alt+M" = "column-focus-tab-previous";
              "Mod+Alt+I" = "column-focus-tab-next";
              "Mod+Alt+Shift+M" = "column-move-tab-previous";
              "Mod+Alt+Shift+I" = "column-move-tab-next";

              # Monitors
              "Mod+Left" = "output-focus-left";
              "Mod+Right" = "output-focus-right";
              "Mod+Shift+Left" = toOutput "left";
              "Mod+Shift+Right" = toOutput "right";

              # Workspaces
              "Mod+Up" = "workspace-previous";
              "Mod+Down" = "workspace-next";
              "Mod+Tab" = once "workspace-focus-last";
              "Mod+WheelUp" = {
                action = "workspace-previous";
                cooldown_ms = 150;
              };
              "Mod+WheelDown" = {
                action = "workspace-next";
                cooldown_ms = 150;
              };
              "Mod+O" = once "overview-toggle";
              "Mod+W" = once "column-toggle-tabbed";
              # scrolling -> dwindle -> master
              "Mod+T" = once "workspace-set-layout:toggle";

              # Sizing
              "Mod+F" = once "window-toggle-maximize";
              "Mod+Ctrl+F" = once "window-toggle-maximize-to-edges";
              "Mod+Shift+F" = once "window-toggle-fullscreen";
              "Mod+R" = "window-cycle-primary-extent";
              "Mod+Shift+R" = "window-cycle-primary-extent-back";
              "Mod+Minus" = "window-modify-primary-extent:-0.05";
              "Mod+Equal" = "window-modify-primary-extent:0.05";
              "Mod+Shift+Minus" = "window-modify-secondary-extent:-0.05";
              "Mod+Shift+Equal" = "window-modify-secondary-extent:0.05";
              "Mod+MouseMiddle" = "layout-scroll-drag";

              # Floating / pinned
              "Mod+Shift+Space" = once "window-toggle-floating";
              "Mod+Shift+Tab" = once "window-focus-switch-floating";
              "Mod+P" = once "window-toggle-pinned";

              "Mod+BracketLeft" = "window-consume-from-right";
              "Mod+BracketRight" = "window-consume-or-expel-right";

              # Scratchpad
              "Mod+Grave" = "scratchpad-toggle";
              "Mod+Shift+Grave" = once "window-move-to-scratchpad";
              "Mod+Ctrl+Grave" = once "window-restore-from-scratchpad";
              "Mod+Alt+Grave" = "scratchpad-focus-next";

              # Hand every key to the focused app (VMs, remote desktop); press
              # again to get shortcuts back.
              "Mod+Shift+Escape" = {
                action = "shortcuts-inhibit-toggle";
                allow_when_inhibited = true;
                repeat = false;
              };

              "Mod+Shift+Q" = once "session-quit:skip-confirmation";

              # Force HDR on for browsers/Jellyfin, or back to auto.
              "Mod+Shift+H" = once "spawn:${lib.getExe hdrToggle}";

              # Media keys
              "XF86AudioPlay" = once "spawn:playerctl play-pause";
              "XF86AudioNext" = "spawn:playerctl next";
              "XF86AudioPrev" = "spawn:playerctl previous";

              # Brightness keys; noctalia shows the OSD on its own.
              "XF86MonBrightnessUp" = whenLocked "spawn:brightnessctl set 5%+";
              "XF86MonBrightnessDown" = whenLocked "spawn:brightnessctl set 5%-";

              # Mission Control key (Mac F3) opens the overview.
              "XF86LaunchA" = once "overview-toggle";
            };
        };
      };
    };
  };
}
