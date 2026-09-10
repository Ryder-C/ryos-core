{
  description = "sputnik: MacBook running Asahi NixOS";

  inputs.core.url = "github:Ryder-C/ryos-core";

  outputs = inputs:
    inputs.core.lib.mkHost {
      inherit inputs;
      name = "sputnik";
      system = "aarch64-linux";
      flakePath = "/home/ryder/sputnik";

      aspects = ry: [
        ry.desktop
        ry.apple-silicon
        ry.laptop
        (ry.charger {device = "macsmc-battery";})
        ry.tailscale
      ];

      aspect = {
        nixos = {
          imports = [./hardware-configuration.nix];
          powerManagement.cpuFreqGovernor = "performance";
        };

        homeManager = {lib, ...}: {
          programs.niri.settings = {
            debug.render-drm-device = "/dev/dri/renderD128";
            switch-events = {
              lid-close.action.spawn = ["sh" "-c" "niri msg action power-off-monitors"];
              lid-open.action.spawn = ["sh" "-c" "sleep 0.5 && niri msg action power-on-monitors"];
            };
            outputs."eDP-1" = {
              mode = {
                width = 3024;
                height = 1964;
                refresh = 120.000;
              };
              scale = 2.0;
            };
          };

          # Laptop bar: drop the desktop widgets, add a battery indicator.
          programs.noctalia.settings = {
            bar.main = {
              start = lib.mkForce ["control-center" "workspaces" "clock_date" "weather" "clock_time"];
              center = lib.mkForce [];
              end = lib.mkForce ["tray" "network" "bluetooth" "notifications" "battery_graphic"];
            };
            widget.battery_graphic = {
              type = "battery";
              display_mode = "graphic";
            };
          };
        };
      };
    };
}
