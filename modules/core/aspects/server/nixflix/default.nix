{
  inputs,
  ry,
  ...
}: let
  rylib = import ../../../_lib.nix;
  ports = {
    jellyfin = 8096;
    seerr = 5055;
    radarr = 7878;
    sonarr = 8989;
    sonarr-anime = 8990;
    prowlarr = 9696;
  };
in {
  flake-file.inputs = {
    vpnconfinement.url = "github:Maroka-chan/VPN-Confinement";
    nixflix = {
      url = "github:kiriwalawren/nixflix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs."vpn-confinement".follows = "vpnconfinement";
    };
  };

  # Jellyfin + Seerr + the *arr stack on /storage, downloading through
  # ry.torrents. Host secrets: jellyfin-api, jellyfin-admin, seerr-api,
  # radarr-api, sonarr-api, sonarr-anime-api, prowlarr-api, arr-password.
  # Extras: ry.nixflix.{onepace,bazarr,autobrr,drainarr,qui,redirecterr}.
  ry.nixflix = {config, ...}: {
    includes = [
      ry.torrents
      config.provides.stack
      config.provides.jellyfin-ui-owned
    ];

    provides = {
      # Parametric so the homepage widgets can carry the arr API keys.
      stack = {host, ...}: let
        key = rylib.secretValue host;
      in {
        nixos = {
          lib,
          secretFile,
          secretValue,
          ...
        }: {
          imports = [inputs.nixflix.nixosModules.default];

          systemd.services = let
            requireStorage.unitConfig.RequiresMountsFor = "/storage";
            afterPia = {
              wants = ["pia-vpn.service"];
              after = ["pia-vpn.service"];
            };
            deps = requireStorage // afterPia;
            # nixflix's hardening sets ProtectSystem=strict with separate
            # ReadWritePaths= for /storage/Torrents and /storage/media/library/*,
            # putting them on different bind mounts inside the service's
            # namespace. link() then returns EXDEV across them and the *arrs
            # fall back to copy. Collapse to a single covering bind mount so
            # hardlinks work.
            hardlinkFix.serviceConfig.ReadWritePaths = lib.mkForce ["/storage"];
          in {
            radarr = deps // hardlinkFix;
            sonarr = deps // hardlinkFix;
            sonarr-anime = deps // hardlinkFix;
            prowlarr = deps;
            jellyfin = requireStorage;
            recyclarr = deps;
            prowlarr-indexers.enable = lib.mkForce false;
          };

          nixflix = {
            enable = true;
            mediaDir = "/storage/media/library";
            stateDir = "/storage/.state";
            downloadsDir = "/storage/Torrents";

            jellyfin = {
              enable = true;
              openFirewall = true;
              apiKey._secret = secretFile "jellyfin-api";
              users.ryder = {
                policy.isAdministrator = true;
                password._secret = secretFile "jellyfin-admin";
              };

              encoding = {
                enableHardwareEncoding = true;
                enableEnhancedNvdecDecoder = true;
                enableTonemapping = true;
                hardwareAccelerationType = "nvenc";
              };

              system.trickplayOptions = {
                enableHwAcceleration = true;
                enableKeyFrameOnlyExtraction = true;
              };

              branding.customCss = ''@import url("https://cdn.jsdelivr.net/gh/lscambo13/ElegantFin@main/Theme/ElegantFin-jellyfin-theme-build-latest-minified.css");'';
            };

            seerr = {
              enable = true;
              openFirewall = true;
              apiKey._secret = secretFile "seerr-api";
              jellyfin.adminPassword._secret = secretFile "jellyfin-admin";
            };

            prowlarr = {
              enable = true;
              openFirewall = true;
              config = {
                apiKey._secret = secretFile "prowlarr-api";
                hostConfig.password = secretValue "arr-password";
              };
            };

            sonarr = {
              enable = true;
              openFirewall = true;
              config = {
                apiKey._secret = secretFile "sonarr-api";
                hostConfig.password = secretValue "arr-password";
              };
            };
            sonarr-anime = {
              enable = true;
              openFirewall = true;
              config = {
                apiKey._secret = secretFile "sonarr-anime-api";
                hostConfig.password = secretValue "arr-password";
              };
            };

            radarr = {
              enable = true;
              openFirewall = true;
              config = {
                apiKey._secret = secretFile "radarr-api";
                hostConfig.password = secretValue "arr-password";
              };
            };

            flaresolverr.enable = true;

            recyclarr = {
              enable = true;
              config = import ./_recyclarr.nix;
              cleanupUnmanagedProfiles = {
                enable = true;
                managedProfiles = ["movies" "shows" "anime"];
              };
            };
          };
        };

        vhost = [
          {
            domain = "ryder.rs";
            sub = "media";
            port = ports.jellyfin;
          }
          {
            domain = "ryder.rs";
            sub = "request";
            port = ports.seerr;
          }
        ];

        homepage = {config, ...}: let
          arr = name: icon: port: secret: {
            group = "Arr";
            inherit name icon;
            href = "http://${config.networking.hostName}:${toString port}";
            widget = {
              type = icon;
              url = "http://localhost:${toString port}";
              key = key secret;
            };
          };
        in [
          {
            group = "Media";
            name = "Jellyfin";
            href = "https://media.ryder.rs";
            icon = "jellyfin";
            widget = {
              type = "jellyfin";
              url = "http://localhost:${toString ports.jellyfin}";
              key = key "jellyfin-api";
            };
          }
          {
            group = "Media";
            name = "Seerr";
            href = "https://request.ryder.rs";
            icon = "seerr";
            widget = {
              type = "seerr";
              url = "http://localhost:${toString ports.seerr}";
              key = key "seerr-api";
            };
          }
          (arr "Radarr" "radarr" ports.radarr "radarr-api")
          (arr "Sonarr" "sonarr" ports.sonarr "sonarr-api")
          (arr "Sonarr Anime" "sonarr" ports.sonarr-anime "sonarr-anime-api")
          (arr "Prowlarr" "prowlarr" ports.prowlarr "prowlarr-api")
        ];
      };

      # nixflix's jellyfin-system-config service POSTs the whole
      # System/Configuration on every activation, including the plugin
      # repository list, wiping repositories added by hand in the UI.
      # Disabling it hands all Jellyfin system settings back to the UI, so the
      # nixflix.jellyfin.{encoding,system,branding} options go inert.
      # jellyfin-plugins was the only unit ordered after it, so repoint that at
      # jellyfin-setup-wizard to keep plugin installs working.
      jellyfin-ui-owned.nixos = {
        lib,
        config,
        ...
      }: {
        systemd.services.jellyfin-system-config.enable = lib.mkForce false;
        systemd.services.jellyfin-plugins = {
          after = lib.mkForce (["jellyfin-setup-wizard.service"] ++ config.nixflix.serviceDependencies);
          requires = lib.mkForce (["jellyfin-setup-wizard.service"] ++ config.nixflix.serviceDependencies);
        };
      };

      onepace = import ./_onepace.nix;
      bazarr = import ./_bazarr.nix;
      autobrr = import ./_autobrr.nix;
      qui = import ./_qui.nix;
      redirecterr = import ./_redirecterr.nix;
    };
  };
}
