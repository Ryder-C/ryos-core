let
  rylib = import ../../_lib.nix;
in {
  ry.input-remapper = {
    includes = [(rylib.groups ["input" "uinput"])];
    nixos.services.input-remapper.enable = true;
  };
}
