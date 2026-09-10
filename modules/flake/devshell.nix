{inputs, ...}: {
  flake-file.inputs.pre-commit-hooks = {
    url = "github:cachix/pre-commit-hooks.nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  perSystem = {
    pkgs,
    system,
    ...
  }: let
    pre-commit-check = inputs.pre-commit-hooks.lib.${system}.run {
      src = ./../..;
      hooks = {
        deadnix.enable = true;
        statix.enable = true;
        alejandra.enable = true;
      };
    };
  in {
    checks.pre-commit-check = pre-commit-check;
    devShells.default = pkgs.mkShell {
      inherit (pre-commit-check) shellHook;
      buildInputs = pre-commit-check.enabledPackages ++ [pkgs.nh];
    };
  };
}
