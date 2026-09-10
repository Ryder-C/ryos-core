let
  rylib = import ../../_lib.nix;
in {
  # `ry.rgb` (AMD board) or `ry.rgb { motherboard = "intel"; }`.
  ry.rgb = {
    description = "OpenRGB with the `main` profile. Optionally call with { motherboard }.";
    __functor = _: {motherboard ? "amd", ...}: {
      nixos = {pkgs, ...}: {
        services.hardware.openrgb = {
          enable = true;
          inherit motherboard;
          startupProfile = "main.orp";
        };
        environment.systemPackages = [pkgs.openrgb-with-all-plugins];
      };

      # Lights off with the screen.
      homeManager = rylib.whenNoctalia {
        programs.noctalia.settings.idle.behavior.rgb-off = {
          timeout = 330;
          command = "openrgb -p off";
          resume_command = "openrgb -p main";
          enabled = true;
        };
      };
    };
  };
}
