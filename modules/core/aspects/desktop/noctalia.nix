{inputs, ...}: let
  rylib = import ../../_lib.nix;
in {
  flake-file.inputs.noctalia = {
    url = "github:noctalia-dev/noctalia-shell";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  ry.noctalia = {
    nixos = {pkgs, ...}: {
      nix.settings = {
        substituters = ["https://noctalia.cachix.org"];
        trusted-public-keys = ["noctalia.cachix.org-1:X+I9x9j4W6h6q5lG2G8uX+5f6L2yU8K5o9y9U+L6J9o="];
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
        (rylib.whenNiri {
          programs.niri.settings = {
            spawn-at-startup = lib.mkAfter [{command = ["noctalia"];}];

            binds = let
              msg = ["noctalia" "msg"];
            in {
              "Mod+Space" = {
                action.spawn = msg ++ ["panel-toggle" "launcher"];
                hotkey-overlay.title = "Toggle Application Launcher";
              };
              "Mod+Y" = {
                action.spawn = msg ++ ["panel-toggle" "control-center" "notifications"];
                hotkey-overlay.title = "Toggle Notifications";
              };
              "Mod+Comma" = {
                action.spawn = msg ++ ["settings-toggle"];
                hotkey-overlay.title = "Toggle Settings";
              };
              "Mod+X" = {
                action.spawn = msg ++ ["panel-toggle" "session"];
                hotkey-overlay.title = "Toggle Power Menu";
              };
              "Mod+V" = {
                action.spawn = msg ++ ["panel-toggle" "clipboard"];
                hotkey-overlay.title = "Toggle Clipboard Manager";
              };

              # Volume keys go through noctalia for the OSD.
              "XF86AudioRaiseVolume" = {
                allow-when-locked = true;
                action.spawn = msg ++ ["volume-up"];
              };
              "XF86AudioLowerVolume" = {
                allow-when-locked = true;
                action.spawn = msg ++ ["volume-down"];
              };
              "XF86AudioMute" = {
                allow-when-locked = true;
                action.spawn = msg ++ ["volume-mute"];
              };

              # Search key (Mac F4) opens the launcher.
              "XF86Search".action.spawn = msg ++ ["panel-toggle" "launcher"];
            };

            layer-rules = [
              {
                matches = [{namespace = "^noctalia-notification";}];
                block-out-from = "screen-capture";
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
            niri_overview_type_to_launch_enabled = true;
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

          idle.behavior = {
            lock = {
              timeout = 600;
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
            auto_update = true;
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
