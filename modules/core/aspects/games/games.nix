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
