{inputs, ...}: {
  flake-file.inputs.rypkgs.url = "github:Ryder-C/rypkgs";

  ry.bluevein.nixos = {
    imports = [inputs.rypkgs.nixosModules.bluevein];
    nixpkgs.overlays = [inputs.rypkgs.overlays.default];
    services.bluevein.enable = true;
  };
}
