{
  description = "sputnik: MacBook running Asahi NixOS";

  inputs.core.url = "github:Ryder-C/ryos-core";

  outputs = inputs:
    inputs.core.lib.mkHost {
      inherit inputs;
      name = "sputnik";
      system = "aarch64-linux";
      flakePath = "/etc/nixos";

      aspects = ry: [
        ry.desktop
        ry.apple-silicon
        ry.laptop
        (ry.charger {device = "macsmc-battery";})
        ry.tailscale
        ry.discord
      ];

      aspect = {
        nixos = {
          imports = [./hardware-configuration.nix];
          powerManagement.cpuFreqGovernor = "performance";
        };

        homeManager = {lib, ...}: {
          # The Apple display controller is a KMS-only device; render on the
          # AGX GPU instead. Read by wlroots at startup, which start-umbriel
          # picks up from the login environment.
          home.sessionVariables.WLR_RENDER_DRM_DEVICE = "/dev/dri/renderD128";

          programs.umbriel.settings = {
            events = {
              lid_close = "umbriel msg dpms-off";
              lid_open = "umbriel msg dpms-on";
            };
            output."eDP-1" = {
              mode = "3024x1964@120";
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
