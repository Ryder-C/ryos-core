{inputs, ...}: {
  flake-file.inputs.agenix = {
    url = "github:ryantm/agenix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  # The module and CLI only. The decrypting identity comes from the user
  # aspect; each secret is declared by the aspect that consumes it.
  ry.agenix.nixos = {pkgs, ...}: {
    imports = [inputs.agenix.nixosModules.default];
    environment.systemPackages = [
      inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
  };
}
