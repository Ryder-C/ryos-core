{inputs, ...}: let
  rylib = import ../../_lib.nix;
in {
  flake-file.inputs = {
    alejandra = {
      url = "github:kamadorueda/alejandra";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # `ry.dev` = tooling common to every language plus all toolchains below.
  # Pick a toolchain with `ry.dev.<name>`.
  ry.dev = {config, ...}: {
    includes =
      [
        # Serial adapters for embedded work.
        (rylib.groups ["dialout"])
      ]
      ++ map (n: config.provides.${n}) ["rust" "node" "python" "typst" "c" "java"];

    homeManager = {pkgs, ...}: {
      imports = [inputs.nix-index-database.homeModules.nix-index];

      home.packages = with pkgs; [
        devenv
        nil
        inputs.alejandra.defaultPackage.${pkgs.stdenv.hostPlatform.system}
        # GPU debugging
        mesa-demos
        vulkan-tools
      ];

      programs = {
        direnv.enable = true;
        nix-index-database.comma.enable = true;
      };
    };

    provides = {
      rust = {
        nixos.nixpkgs.overlays = [inputs.rust-overlay.overlays.default];
        homeManager = {pkgs, ...}: {
          home.packages = [
            (pkgs.rust-bin.stable.latest.default.override {
              extensions = ["rust-src" "rustfmt" "clippy"];
              targets = ["${pkgs.stdenv.hostPlatform.qemuArch}-unknown-linux-gnu"];
            })
            pkgs.rust-analyzer
          ];
        };
      };

      node.homeManager = {pkgs, ...}: {
        home.packages = [pkgs.nodejs];
      };

      python.homeManager = {pkgs, ...}: {
        home.packages = with pkgs; [
          python3
          python3Packages.setuptools
          python3Packages.virtualenv
          python3Packages.gmpy2
        ];
        home.shellAliases.py = "python";
      };

      typst.homeManager = {pkgs, ...}: {
        home.packages = with pkgs; [typst typstyle tinymist];
      };

      c.homeManager = {pkgs, ...}: {
        home.packages = with pkgs; [gcc gnumake valgrind];
      };

      java.homeManager = {pkgs, ...}: {
        home.packages = [pkgs.jdk25];
      };
    };
  };
}
