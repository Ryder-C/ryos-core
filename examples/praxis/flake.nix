{
  description = "praxis: desktop workstation";

  inputs = {
    core.url = "github:Ryder-C/ryos-core";
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
  };

  outputs = inputs:
    inputs.core.lib.mkHost {
      inherit inputs;
      name = "praxis";
      system = "x86_64-linux";
      flakePath = "/home/ryder/praxis";

      aspects = ry: [
        ry.desktop
        ry.nvidia
        ry.discord
        ry.spotify
        ry.steam
        ry.steam.presence
        ry.games
        ry.aagl
        ry.davinci-resolve
        ry.torrents
        ry.ollama
        ry.rgb
        ry.bluevein
        ry.activitywatch
        ry.librepods
        ry.flatpak
        ry.flatpak.sober
        ry.flatpak.plex
        ry.flatpak.hytale
        ry.flatpak.jellium
        ry.tailscale
        ry.gpu-screen-recorder
        ry.gpu-screen-recorder.replay
        ry.obs
        ry.docker
        ry.libvirt
        ry.waydroid
        ry.irc
        ry.toys
      ];

      aspect = {
        nixos = {
          pkgs,
          lib,
          ...
        }: {
          imports = [./hardware-configuration.nix];

          nixpkgs.overlays = [inputs.nix-cachyos-kernel.overlays.default];
          boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest;
          boot.kernelModules = ["wacom"];

          nix = {
            package = lib.mkForce pkgs.lix;
            settings = {
              substituters = ["https://attic.xuyh0120.win/lantian"];
              trusted-public-keys = ["lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="];
            };
          };

          powerManagement.cpuFreqGovernor = "performance";

          hardware = {
            flipperzero.enable = true;
            opentabletdriver.enable = true;
          };

          # Disable the ghost MediaTek bluetooth adapter (0e8d:0616).
          services.udev.extraRules = ''
            SUBSYSTEM=="usb", ATTR{idVendor}=="0e8d", ATTR{idProduct}=="0616", ATTR{authorized}="0"
          '';

          # Nvidia high VRAM usage fix for Niri (and other Wayland compositors)
          # https://yalter.github.io/niri/Nvidia.html#high-vram-usage-fix
          environment.etc."nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json".text = builtins.toJSON {
            rules = [
              {
                pattern = {
                  feature = "procname";
                  matches = "niri";
                };
                profile = "Limit Free Buffer Pool On Wayland Compositors";
              }
            ];
            profiles = [
              {
                name = "Limit Free Buffer Pool On Wayland Compositors";
                settings = [
                  {
                    key = "GLVidHeapReuseRatio";
                    value = 0;
                  }
                ];
              }
            ];
          };
        };

        homeManager.programs.niri.settings = {
          outputs = {
            "HDMI-A-1" = {
              mode = {
                width = 3840;
                height = 2160;
                refresh = 239.995;
              };
              scale = 1.5;
              variable-refresh-rate = false;
              position = {
                x = 0;
                y = 0;
              };
            };
            "DP-2" = {
              mode = {
                width = 3840;
                height = 2160;
                refresh = 59.997;
              };
              scale = 1.5;
              position = {
                x = -2560;
                y = 0;
              };
            };
          };
          window-rules = [
            {
              matches = [{app-id = "^net\\.nullsum\\.JelliumDesktop$";}];
              open-on-output = "DP-3";
            }
          ];
        };
      };
    };
}
