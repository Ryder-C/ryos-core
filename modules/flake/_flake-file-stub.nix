# Host flakes evaluate the core modules without flake-file (their flake.nix is
# hand-written and lists only `core`). The aspects still declare
# `flake-file.inputs.*`, so give those declarations an inert option to land in.
{lib, ...}: {
  options.flake-file.inputs = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.anything;
    default = {};
    description = "Ignored: flake inputs are pinned by the core flake.";
  };
}
