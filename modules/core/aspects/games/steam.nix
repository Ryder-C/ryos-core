{inputs, ...}: {
  flake-file.inputs = {
    steam-presence = {
      url = "github:JustTemmie/steam-presence";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    proton-cachyos-nix = {
      url = "github:powerofthe69/proton-cachyos-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # Steam, gamescope, gamemode, proton-cachyos.
  # ry.steam.presence: Discord rich presence (needs the `steam_key` secret).
  # ry.steam.kiosk: headless 4K gamescope session for streaming.
  ry.steam = {
    nixos = {pkgs, ...}: {
      programs = {
        steam = {
          enable = true;
          protontricks.enable = true;
          extraCompatPackages = [
            pkgs.proton-ge-bin
            inputs.proton-cachyos-nix.packages.${pkgs.stdenv.hostPlatform.system}.proton-cachyos-x86_64-v3
          ];
        };
        gamescope = {
          enable = true;
          capSysNice = false;
        };
        gamemode = {
          enable = true;
          enableRenice = true;
        };
      };

      # Steam's FHS env, for running other binaries that expect a normal distro.
      environment.systemPackages = [pkgs.steam-run];

      hardware.steam-hardware.enable = true;
      hardware.graphics.enable32Bit = true;

      # Some games (and proton) exhaust the defaults.
      boot.kernel.sysctl = {
        "vm.max_map_count" = 16777216;
        "fs.file-max" = 524288;
      };
    };

    homeManager = {pkgs, ...}: let
      proton-cachyos = inputs.proton-cachyos-nix.packages.${pkgs.stdenv.hostPlatform.system}.proton-cachyos-x86_64-v3;
    in {
      home.packages = with pkgs; [
        winetricks
        mangohud
        proton-cachyos
      ];

      # Expose proton-cachyos to Heroic (it scans this dir; Steam reads
      # extraCompatPackages via env var instead, so it doesn't end up here).
      # The `steamcompattool` output is the one with `proton`,
      # `compatibilitytool.vdf`, etc.
      home.file.".steam/root/compatibilitytools.d/proton-cachyos".source = proton-cachyos.steamcompattool;
    };

    provides = {
      presence.nixos = {
        secretFile,
        ageSecret,
        ...
      }: {
        imports = [inputs.steam-presence.nixosModules.steam-presence];
        programs.steam.presence = {
          enable = true;
          steamApiKeyFile = secretFile "steam_key";
          userIds = ["76561198311078521"];
        };
        age.secrets = ageSecret "steam_key" {
          owner = "ryder";
          mode = "0400";
        };
      };

      kiosk.nixos.programs.steam.gamescopeSession = {
        enable = true;
        args = [
          "-W 3840"
          "-H 2160"
          "-w 3840"
          "-h 2160"
          "-r 60"
          "-o 60"
          "--force-grab-cursor"
        ];
      };
    };
  };
}
