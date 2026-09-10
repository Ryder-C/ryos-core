{inputs, ...}: {
  flake-file.inputs.rycharger = {
    url = "github:Ryder-C/rycharger";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  # Callable: `ry.charger { device = "macsmc-battery"; }`.
  ry.charger = {
    description = "Battery charge limiter (rycharger). Call with { device }.";
    __functor = _: {
      # den would otherwise defer a bare `ry.charger` forever, silently.
      device ? throw "ry.charger must be called: (ry.charger { device = \"BAT0\"; })",
      ...
    }: {
      nixos = {
        imports = [inputs.rycharger.nixosModules.default];
        services.rycharger = {
          enable = true;
          settings.battery.device = device;
        };
      };
    };
  };
}
