{
  inputs,
  lib,
  ...
}: {
  flake-file.inputs.den.url = lib.mkDefault "github:denful/den";

  imports = [
    inputs.den.flakeModule
    # `ry` is the namespace every aspect lives in; also exported as
    # flake.denful.ry for flakes that only want the data (no callables).
    (inputs.den.namespace "ry" true)
  ];
}
