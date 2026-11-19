{inputs, ...}: let
  rylib = import ../../_lib.nix;
in {
  # Binary cache only: the `cachix` branch trails main to the newest commit
  # CI has pushed, and overriding any input (nixpkgs.follows included)
  # changes the hash and misses the cache.
  flake-file.inputs.noctalia.url = "github:noctalia-dev/noctalia/cachix";

  ry.noctalia = {
    nixos = {pkgs, ...}: {
      nix.settings = {
        substituters = ["https://noctalia.cachix.org"];
        trusted-public-keys = ["noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="];
      };

      # Lets the drive-health plugin read SMART as the session user; its own
      # route installs a root collector into /usr/local, which NixOS lacks.
      # dac_override opens /dev/nvme0 (0600 root), sys_admin does the NVMe
      # admin ioctl, sys_rawio does SG_IO on /dev/sd*.
      # NOTE: dac_override + sys_admin on a world-executable binary is
      # root-equivalent in practice; that is the price of SMART without a
      # privileged collector.
      security.wrappers.smartctl = {
        source = "${pkgs.smartmontools}/bin/smartctl";
        owner = "root";
        group = "root";
        capabilities = "cap_dac_override,cap_sys_rawio,cap_sys_admin+ep";
      };
    };

    homeManager = {
      config,
      lib,
      pkgs,
      ...
    }: let
      wallpaperDir = "${config.home.homeDirectory}/Pictures/Wallpapers";
    in {
      imports = [
        inputs.noctalia.homeModules.default
        (rylib.whenUmbriel {
          programs.umbriel.settings = {
            general.autostart = ["noctalia"];

            keybinds = let
              msg = cmd: "spawn noctalia msg ${cmd}";
              once = cmd: {
                action = msg cmd;
                repeat = false;
              };
              whenLocked = cmd: {
                action = msg cmd;
                allow_when_locked = true;
              };
            in {
              "Mod+Space" = once "panel-toggle launcher";
              "Mod+Y" = once "panel-toggle control-center notifications";
              "Mod+Comma" = once "settings-toggle";
              "Mod+X" = once "panel-toggle session";
              "Mod+V" = once "panel-toggle clipboard";
              # Held-modifier switcher: tap for the last window, hold to pick.
              "Alt+Tab" = once "window-switcher hold";

              # Screenshots go through noctalia's capture (piped to satty below).
              "Mod+S" = once "screenshot-region";
              "Mod+Shift+S" = once "screenshot-fullscreen";
              # Freeze every monitor and annotate over it.
              "Mod+Alt+S" = once "screenshot-annotate";

              # Volume keys go through noctalia for the OSD.
              "XF86AudioRaiseVolume" = whenLocked "volume-up";
              "XF86AudioLowerVolume" = whenLocked "volume-down";
              "XF86AudioMute" = (whenLocked "volume-mute") // {repeat = false;};

              # Search key (Mac F4) opens the launcher.
              "XF86Search" = once "panel-toggle launcher";
            };

            # Blur behind the bar, panels, notifications and OSDs. Panels and
            # popups open over windows, so they blur the live content behind
            # them; the bar only covers the wallpaper and keeps the cheaper
            # cached blur.
            layer_rule = [
              {
                match.namespace = "^noctalia-(bar-[^\"]+|notification|dock|panel|attached-panel|osd)$";
                blur = true;
                blur_ignore_alpha = 0.5;
                blur_popups = true;
              }
              {
                match.namespace = "^noctalia-(notification|dock|panel|attached-panel|osd)$";
                blur_optimized = false;
              }
            ];
          };
        })
      ];

      # Seed the picker's directory with the repo's wallpapers. Copied rather
      # than symlinked so they stay writable; -n means an existing file is
      # never touched, so this only fills in what's missing.
      home.activation.wallpapers = lib.hm.dag.entryAfter ["writeBoundary"] ''
        run mkdir -p "${wallpaperDir}"
        run cp -rnT --no-preserve=mode ${../../../../wallpapers} "${wallpaperDir}"
      '';

      # smartctl is deliberately absent: it comes from the wrapper above, so
      # the only one on PATH carries the capabilities.
      home.packages = with pkgs; [
        satty
        fastfetch
      ];

      programs.noctalia = {
        enable = true;
        package = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;

        settings = {
          shell = {
            polkit_agent = true;
            avatar_path = "${config.home.homeDirectory}/.face";
            corner_radius_scale = 1.0;
            clipboard_enabled = true;
            umbriel_overview_type_to_launch_enabled = true;
            settings_show_advanced = true;
            screenshot = {
              pipe_to_command = true;
              pipe_command = "satty -f -";
            };
          };

          theme = {
            mode = "dark";
            source = "builtin";
            builtin = "Catppuccin";
          };

          weather = {
            enabled = true;
            unit = "imperial";
          };

          location = {
            auto_locate = true;
            address = "Cardiff by the Sea, United States";
          };

          wallpaper = {
            enabled = true;
            directory = wallpaperDir;
            transition_on_startup = true;
            automation = {
              enabled = false;
              order = "random";
              recursive = true;
            };
          };

          system.monitor.enabled = true;

          # Lock must fire before screen-off. When the session locks, noctalia
          # re-arms every idle behavior and runs the resume action of any that
          # already idled (so screen_off is undone on unlock); done in the other
          # order that re-lights the monitors and RGB at the lock timeout with
          # nobody at the desk. Keep any behavior that idles the display, e.g.
          # rgb-off in rgb.nix, at a timeout >= lock.timeout.
          idle.behavior = {
            lock = {
              timeout = 300;
              enabled = true;
              action = "lock";
            };
            "screen-off" = {
              timeout = 330;
              enabled = true;
              action = "screen_off";
            };
          };

          bar.main = {
            position = "top";
            background_opacity = 0.93;
            capsule = true;
            margin_edge = 0;
            margin_ends = 0;
            padding = 7;
            radius = 0;
            start = ["control-center" "workspaces" "sysmon_cpu" "nix-monitor" "summary"];
            center = ["clock_date" "clock_time" "weather"];
            end = ["tray" "network" "bluetooth" "notifications"];
          };

          # Plugin code is still cloned by noctalia itself into
          # ~/.local/state/noctalia/plugins; only the on/off and settings live here.
          plugins = {
            enabled = [
              "noctalia/bitwarden"
              "avivbintangaringga/nix-monitor"
              "gustav0ar/drive-health"
            ];
            auto_update = "all";
          };

          widget = {
            "control-center".glyph = "snowflake";
            workspaces = {
              type = "workspaces";
              show_labels = false;
            };
            sysmon_cpu = {
              type = "sysmon";
              stat = "cpu_usage";
            };
            clock_date = {
              type = "clock";
              format = "{:%a, %b %d}";
            };
            clock_time = {
              type = "clock";
              format = "{:%-I:%M %p}";
            };
            network = {
              type = "network";
              show_label = false;
            };
            bluetooth = {
              type = "bluetooth";
              show_label = false;
            };
            tray = {
              type = "tray";
              pinned = ["Battery Status"];
            };

            # Plugin-provided widgets.
            nix-monitor.type = "avivbintangaringga/nix-monitor:nix-monitor";
            summary.type = "gustav0ar/drive-health:summary";
          };
        };
      };
    };
  };
}
