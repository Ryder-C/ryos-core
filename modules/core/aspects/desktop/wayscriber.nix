{inputs, ...}: let
  rylib = import ../../_lib.nix;
in {
  flake-file.inputs.wayscriber = {
    url = "github:devmobasa/wayscriber";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  # Screen annotation overlay on Mod+D (niri only).
  ry.wayscriber.homeManager = {pkgs, ...}: let
    # wayscriber's test suite is sandbox-hostile: it spawns daemon processes,
    # probes caller-PID liveness, and races reading fixture-report files, so
    # different tests fail non-deterministically under `nix build`.
    wayscriber = inputs.wayscriber.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (_: {
      doCheck = false;
    });
  in {
    imports = [
      (rylib.whenNiri {
        # WAYSCRIBER_NO_DETACH: with `--active`, wayscriber re-spawns itself
        # through its internal process broker, which only permits programs whose
        # basename is "wayscriber" or starts with "wayscriber-". makeBinaryWrapper
        # renames the real binary to `.wayscriber-wrapped`, so current_exe() fails
        # that check and the overlay exits immediately (silently, since niri
        # discards its stderr). Skipping the detach runs the overlay in the
        # foreground instead, which is what upstream's own daemon does.
        programs.niri.settings.binds."Mod+D".action.spawn = [
          "${pkgs.coreutils}/bin/env"
          "WAYSCRIBER_NO_DETACH=1"
          "${wayscriber}/bin/wayscriber"
          "--active"
        ];
      })
    ];
  };
}
