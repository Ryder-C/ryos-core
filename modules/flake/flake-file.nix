# flake-file generates flake.nix from the `flake-file.inputs` declared across
# modules/. Every aspect declares the inputs it needs next to its use; only the
# inputs shared by the framework itself live here. Regenerate with
# `nix run .#write-flake`.
{inputs, ...}: {
  imports = [(inputs.flake-file.flakeModules.dendritic or {})];

  systems = ["x86_64-linux" "aarch64-linux"];

  # Same formatter as `nix fmt`, so the generated file stays check-clean.
  flake-file.formatter = pkgs: pkgs.alejandra;

  flake-file.inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-lib.follows = "nixpkgs";
    # Fallback for packages that are broken on unstable; exposed to every class
    # as the `stablePkgs` module argument (see modules/core/defaults.nix).
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs-lib";
    };
    flake-file.url = "github:vic/flake-file";
    import-tree.url = "github:vic/import-tree";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
