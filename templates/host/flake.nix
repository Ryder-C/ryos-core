{
  description = "CHANGEME host";

  # Everything else (nixpkgs, home-manager, den, ...) is pinned by core.
  # `nix flake update core` moves the whole system.
  inputs.core.url = "github:Ryder-C/ryos-core";

  outputs = inputs:
    inputs.core.lib.mkHost {
      inherit inputs;
      name = "CHANGEME";
      system = "x86_64-linux";
      users = ["ryder"];
      # Where nh and the `ns`/`nst`/`nsb` aliases find this flake:
      flakePath = "/home/ryder/CHANGEME";

      facts = {
        # nvidia.open = false;
        # nvidia.driver = "legacy_580";
        # Instance-local secrets, as strings or paths in this (private) repo.
        # Each aspect documents the names it needs.
        secrets = {};
      };

      aspects = ry: [
        ry.desktop
        # ry.nvidia
        # ry.steam
        # ry.steam.presence
        # (ry.charger { device = "BAT0"; })
      ];

      aspect = {
        nixos = {
          imports = [./hardware-configuration.nix];
        };
        homeManager = {
          # programs.niri.settings.outputs."DP-1" = { ... };
        };
      };
    };
}
