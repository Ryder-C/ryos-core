# Sample hosts built through mkHost so `nix flake check` evaluates every
# aspect (it instantiates nixosConfigurations without building them).
{
  inputs,
  config,
  ...
}: let
  ci = name: system: args:
    (config.flake.lib.mkHost ({inherit inputs name system;} // args)).nixosConfigurations.${name};

  fakeDisk.nixos = {
    fileSystems."/" = {
      device = "/dev/fake";
      fsType = "ext4";
    };
    fileSystems."/boot" = {
      device = "/dev/fake-boot";
      fsType = "vfat";
    };
  };

  placeholderSecrets = builtins.listToAttrs (map (n: {
      name = n;
      value = "ci-placeholder";
    }) [
      "jellyfin-api"
      "jellyfin-admin"
      "seerr-api"
      "radarr-api"
      "sonarr-api"
      "sonarr-anime-api"
      "prowlarr-api"
      "arr-password"
      "bazarr-api"
      "autobrr"
      "autobrr-api"
      "qui"
      "vaultwarden"
      "cross-seed"
      "anilist"
      "matrix-registration"
    ]);
in {
  flake.nixosConfigurations = {
    ci-desktop = ci "ci-desktop" "x86_64-linux" {
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
        ry.wayscriber
        ry.gpu-screen-recorder
        ry.gpu-screen-recorder.replay
        ry.obs
        ry.docker
        ry.libvirt
        ry.waydroid
        ry.irc
        ry.toys
      ];
      aspect = fakeDisk;
    };

    ci-laptop = ci "ci-laptop" "aarch64-linux" {
      aspects = ry: [
        ry.desktop
        ry.apple-silicon
        ry.laptop
        (ry.charger {device = "macsmc-battery";})
        ry.tailscale
      ];
      aspect = {
        includes = [fakeDisk];
        # A real host points hardware.asahi.peripheralFirmwareDirectory at
        # /boot/asahi from its hardware-configuration.nix.
        nixos.hardware.asahi.extractPeripheralFirmware = false;
      };
    };

    ci-server = ci "ci-server" "x86_64-linux" {
      users = ["ryder" "adin"];
      facts = {
        nvidia = {
          open = false;
          driver = "legacy_580";
        };
        secrets = placeholderSecrets;
      };
      aspects = ry: [
        ry.server
        ry.nvidia
        ry.audio
        ry.rgb
        ry.tailscale
        ry.homepage
        ry.caddy
        ry.vaultwarden
        ry.uptime-kuma
        ry.minecraft
        ry.guessr
        ry.nixflix
        ry.nixflix.onepace
        ry.nixflix.bazarr
        ry.nixflix.autobrr
        ry.nixflix.drainarr
        ry.nixflix.qui
        ry.nixflix.redirecterr
        ry.nixflix.seadexerr
        ry.nixflix.arr-mcp
        ry.matrix
        ry.steam
        ry.steam.kiosk
        ry.ai
      ];
      aspect = fakeDisk;
    };
  };
}
