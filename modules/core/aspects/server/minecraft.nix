{inputs, ...}: {
  flake-file.inputs.nix-minecraft.url = "github:Infinidoge/nix-minecraft";

  ry.minecraft = {
    nixos = {
      pkgs,
      config,
      ...
    }: let
      voiceChat = pkgs.fetchurl {
        url = "https://cdn.modrinth.com/data/9eGKb6K1/versions/ZQfVgh62/voicechat-bukkit-2.6.16.jar";
        sha256 = "0c7z56qkd2avn49135jhk42b5dxn0rixsjcs5bzrnaqkylaw3dyj";
      };
      blueMap = pkgs.fetchurl {
        url = "https://cdn.modrinth.com/data/swbUV1cr/versions/jPyegm5Q/bluemap-5.20-paper.jar";
        sha256 = "0fb3h3g9wx36mnmzcw944mzs74lyjyka3b5p0jd0i9wafa5wjff9";
      };
      distantHorizons = pkgs.fetchurl {
        url = "https://cdn.modrinth.com/data/IjY7seTG/versions/O7tD7FNe/DistantHorizonsSupport-0.13.0.jar";
        sha256 = "1vz40sck9an2xikfsb9lalls3ayv1h8qbw26qn6v5c1zxjpcz6sw";
      };

      # RCON is localhost-only (never firewalled open); lazymc uses it to issue
      # a graceful `stop`. The password lands world-readable in server.properties
      # in the nix store, which is fine since RCON is not exposed off-host.
      rconPassword = "lazymc-genius-vanilla";

      # lazymc listens on the public port and only starts the real server (on
      # an internal port) when a player connects, then stops it after an idle
      # timeout.
      lazymcConfig = (pkgs.formats.toml {}).generate "lazymc.toml" {
        public.address = "0.0.0.0:25565";
        server = {
          address = "127.0.0.1:25566";
          # `--wait` blocks until the unit stops, giving lazymc a process to monitor.
          command = "${config.systemd.package}/bin/systemctl start --wait minecraft-server-genius-vanilla.service";
          freeze_process = false; # full stop to actually free the 12G, not SIGSTOP
          wake_on_start = false;
          wake_on_crash = true;
        };
        time = {
          sleep_after = 900;
          minimum_online_time = 60;
        };
        rcon = {
          enabled = true;
          port = 25575;
          password = rconPassword;
          randomize_password = false; # can't rewrite the read-only store server.properties
        };
        advanced.rewrite_server_properties = false;
      };
    in {
      imports = [inputs.nix-minecraft.nixosModules.minecraft-servers];
      nixpkgs.overlays = [inputs.nix-minecraft.overlay];

      networking.firewall = {
        allowedTCPPorts = [25565]; # lazymc (public Minecraft port)
        allowedUDPPorts = [8100 24454]; # bluemap, voice chat
      };

      services.minecraft-servers = {
        enable = true;
        eula = true;
        # lazymc owns the public port; the real server binds an internal port
        # that must stay closed to the outside.
        openFirewall = false;
        managementSystem.systemd-socket.enable = true;

        servers.genius-vanilla = {
          enable = true;
          autoStart = false; # lazymc starts it on demand
          restart = "no"; # don't auto-restart after lazymc's graceful RCON stop
          package = pkgs.purpur-server.override {jre = pkgs.jdk25;};

          serverProperties = {
            server-port = 25566;
            enable-rcon = true;
            "rcon.port" = 25575;
            "rcon.password" = rconPassword;
            broadcast-rcon-to-ops = false;

            white-list = true;
            enforce-secure-profile = false;
            spawn-protection = 0;
            difficulty = 3;
            gamemode = 0;
            motd = "i guess";

            view-distance = 16;
            simulation-distance = 10;
          };

          files = {
            "plugins/voicechat-bukkit-2.6.16.jar" = voiceChat;
            "plugins/bluemap-5.20-paper.jar" = blueMap;
            "plugins/DistantHorizonsSupport-0.13.0.jar" = distantHorizons;
          };

          jvmOpts = "-Xmx12G -Xms12G -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true";
        };
      };

      systemd.services.lazymc-genius-vanilla = {
        description = "lazymc wake-on-demand proxy for genius-vanilla";
        wantedBy = ["multi-user.target"];
        after = ["network.target"];
        serviceConfig = {
          ExecStart = "${pkgs.lazymc}/bin/lazymc -c ${lazymcConfig} start";
          Restart = "always";
          RestartSec = 5;
          # runs as root so it can `systemctl start` the minecraft unit
        };
      };
    };

    homepage = {config, ...}: {
      group = "Game";
      name = "Minecraft";
      href = "http://${config.networking.hostName}:8100";
      icon = "minecraft";
      widget = {
        type = "minecraft";
        url = "udp://localhost:25565";
      };
    };
  };
}
