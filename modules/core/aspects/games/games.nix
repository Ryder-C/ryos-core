{
  # Launchers and game tooling. `ry.games` = all; `ry.games.<name>` picks one.
  ry.games = {config, ...}: {
    includes = map (n: config.provides.${n}) ["heroic" "lutris" "bottles" "prism" "osu" "minecraft-tools"];

    provides = {
      heroic.homeManager = {pkgs, ...}: {
        home.packages = [pkgs.heroic];
      };

      lutris.homeManager = {stablePkgs, ...}: {
        home.packages = [stablePkgs.lutris];
      };

      bottles.homeManager = {
        pkgs,
        stablePkgs,
        ...
      }: {
        home.packages = [
          (stablePkgs.bottles.override {removeWarningPopup = true;})
          pkgs.wineWow64Packages.waylandFull
        ];
      };

      # "Open to LAN" binds a random ephemeral port (kernel range
      # 32768-60999) unless one is typed into the dialog (1024-65535).
      # UDP 4445 is the multicast LAN-world announcement.
      prism.nixos.networking.firewall = {
        allowedTCPPortRanges = [
          {
            from = 32768;
            to = 60999;
          }
        ];
        allowedUDPPorts = [4445];
      };

      prism.homeManager = {
        pkgs,
        stablePkgs,
        ...
      }: {
        home.packages = [stablePkgs.prismlauncher pkgs.libxkbcommon];
      };

      osu.homeManager = {pkgs, ...}: {
        home.packages = [pkgs.osu-lazer];
      };

      # Speedrun tooling.
      minecraft-tools.homeManager = {pkgs, ...}: {
        home.packages = with pkgs; [waywall glfw3-minecraft];
      };
    };
  };
}
