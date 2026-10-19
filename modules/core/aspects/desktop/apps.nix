{inputs, ...}: let
  rylib = import ../../_lib.nix;
in {
  flake-file.inputs.vesc-tool.url = "github:vedderb/vesc_tool";

  # Graphical (and a few CLI) applications grouped by purpose. `ry.apps` pulls
  # in everything; `ry.apps.<group>` picks one group. Packages that do not
  # exist for the host's platform are skipped.
  ry.apps = {config, ...}: {
    includes = map (n: config.provides.${n}) ["office" "media" "privacy" "making" "utils"];

    provides = {
      office.homeManager = {
        pkgs,
        lib,
        ...
      }: {
        home.packages = rylib.availableOn pkgs lib (with pkgs; [
          obsidian
          zathura
          tdf
          qalculate-gtk
          kdePackages.kleopatra
          zoom-us
          todo
        ]);
        home.shellAliases.pdf = "tdf";
      };

      media = {
        # fladder's mpv-unwrapped buildInput pulls in mpv.pc, which declares
        # `Requires: libass`; libass isn't in buildInputs so pkg-config fails.
        # And nixpkgs' flutter wrapper bakes in an aapt2 that is x86_64-only,
        # which makes every flutter app refuse to evaluate on aarch64-linux;
        # aapt2 is only used for Android builds, so stub it out there.
        nixos.nixpkgs.overlays = [
          (final: prev: {
            fladder = prev.fladder.overrideAttrs (o: {
              buildInputs = o.buildInputs ++ [final.libass];
            });
            aapt =
              if prev.stdenv.hostPlatform.system == "aarch64-linux"
              then
                final.writeShellScriptBin "aapt2" ''
                  echo "aapt2 is not available on aarch64-linux" >&2
                  exit 1
                ''
              else prev.aapt;
          })
        ];
        homeManager = {
          config,
          pkgs,
          lib,
          ...
        }: {
          home.packages = rylib.availableOn pkgs lib (with pkgs; [
            audacity
            ffmpeg
            fladder
            gifsicle
            imv
            jellyfin-desktop
            libvlc
          ]);

          # Cast target for Jellyfin (web UI / phone app -> "mpv-shim"),
          # playing in a native mpv window. jellyfin-desktop can't do HDR: it
          # draws libmpv into an sRGB Qt surface. hint=yes tags the surface
          # with the video's own colorspace even while the output is SDR, which
          # is what umbriel's hdr = "auto" waits for (mpv's default only hints
          # when the display already advertises HDR).
          services.jellyfin-mpv-shim = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
            enable = true;
            mpvConfig = {
              vo = "gpu-next";
              gpu-api = "vulkan";
              target-colorspace-hint = "yes";
              target-colorspace-hint-mode = "source";
            };
          };
          # 3.x ships its own library browser and opens it at login; start in
          # the tray so only casts bring up a window. A CLI flag rather than
          # `settings`, which would make the shim's self-written conf.json a
          # read-only symlink.
          systemd.user.services.jellyfin-mpv-shim.Service.ExecStart =
            lib.mkIf pkgs.stdenv.hostPlatform.isLinux
            (lib.mkForce "${lib.getExe config.services.jellyfin-mpv-shim.package} --minimized");
        };
      };

      privacy.homeManager = {
        pkgs,
        lib,
        ...
      }: {
        home.packages = rylib.availableOn pkgs lib (with pkgs; [
          bitwarden-cli
          bleachbit
          monero-gui
          tor-browser
        ]);
      };

      making.homeManager = {
        pkgs,
        lib,
        stablePkgs,
        ...
      }: {
        home.packages = rylib.availableOn pkgs lib (with pkgs; [
          kicad
          lorien
          orca-slicer
          unityhub
          stablePkgs.blender
          (inputs.vesc-tool.packages.${pkgs.stdenv.hostPlatform.system}.default or null)
        ]);
      };

      utils = {
        nixos = {pkgs, ...}: {
          environment.systemPackages = with pkgs; [
            appimage-run
            gparted
          ];
        };
        homeManager = {
          pkgs,
          lib,
          ...
        }: {
          home.packages = rylib.availableOn pkgs lib (with pkgs; [
            baobab
            gtt
            leetgo
          ]);
        };
      };
    };
  };
}
