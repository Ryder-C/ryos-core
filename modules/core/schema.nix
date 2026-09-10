# Typed host facts. Hosts set these through `mkHost { facts = { ... }; }`;
# aspects read them as `host.<fact>` (parametric or flat-form class modules).
{lib, ...}: {
  den.schema.user.config.classes = lib.mkDefault ["homeManager"];

  den.schema.host = {
    options = {
      flakePath = lib.mkOption {
        type = lib.types.str;
        description = "Path of this host's flake on disk, used by nh and the shell aliases.";
      };

      secrets = lib.mkOption {
        type = lib.types.attrsOf (lib.types.either lib.types.str lib.types.path);
        default = {};
        description = ''
          Instance-local secrets supplied by the (private) host flake, either as a
          literal string or as a path to a file in the host repo. Aspects read them
          with the `secretFile`/`secretValue` module arguments. Both forms end up
          world-readable in /nix/store on this host; use agenix (core `secrets/`)
          for anything account-scoped.
        '';
      };

      nvidia = {
        open = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Use the open kernel modules (Turing+). Pascal and older need false.";
        };
        driver = lib.mkOption {
          type = lib.types.str;
          default = "latest";
          description = "Attribute of `boot.kernelPackages.nvidiaPackages` to install, e.g. `legacy_580`.";
        };
      };
    };
  };
}
