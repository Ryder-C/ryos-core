{inputs, ...}: {
  flake-file.inputs.aagl = {
    url = "github:ezKEa/aagl-gtk-on-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  ry.aagl.nixos = {
    imports = [inputs.aagl.nixosModules.default];
    nix.settings = inputs.aagl.nixConfig;
    programs.anime-game-launcher.enable = true;
  };
}
