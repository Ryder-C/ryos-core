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

          # Nvidia high VRAM usage fix for Wayland compositors
          # https://yalter.github.io/niri/Nvidia.html#high-vram-usage-fix
          # Both names: the package's makeBinaryWrapper execs the real binary
          # as `.umbriel-wrapped`.
          environment.etc."nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json".text = builtins.toJSON {
            rules =
              map (name: {
                pattern = {
                  feature = "procname";
                  matches = name;
                };
                profile = "Limit Free Buffer Pool On Wayland Compositors";
              }) ["umbriel" ".umbriel-wrapped"];
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

        # HDR switches on by itself for fullscreen content that tags itself
        # HDR (see PROTON_ENABLE_WAYLAND in the umbriel aspect); VRR only
        # while something is fullscreen (the desktop stays at fixed refresh,
        # as it was under niri); tearing only for fullscreen windows that ask
        # for it.
        # `umbriel color` / `umbriel tearing` show what actually engaged.
        homeManager.programs.umbriel.settings.output = let
          gaming = {
            scale = 1.5;
            hdr = "auto";
            vrr = "fullscreen";
            tearing = true;
            direct_scanout = true;
          };
        in {
          "HDMI-A-1" =
            gaming
            // {
              mode = "3840x2160@239.995";
              position = [0 0];
              focus_at_startup = true;
            };
          "DP-2" =
            gaming
            // {
              mode = "3840x2160@59.997";
              position = [(-2560) 0];
            };
        };
      };
    };
}
