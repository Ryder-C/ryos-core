{inputs, ...}: {
  flake-file.inputs.gamesir-linux-tools = {
    url = "git+https://codeberg.org/Epaphroditus/gamesir-linux-tools-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  # Deadband: GameSir controller config GUI (deadzones, triggers, rebinds).
  # The module installs it plus the hidraw udev rules it needs. The
  # controller must be in Xbox/XInput mode for the vendor HID protocol.
  ry.deadband.nixos = {
    imports = [inputs.gamesir-linux-tools.nixosModules.default];
  };
}
