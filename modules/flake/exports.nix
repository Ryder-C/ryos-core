# The public surface of the core flake:
#   flakeModules.default  - den + every aspect, importable by any flake-parts flake
#   lib.mkHost            - one-call host flake (see templates/host)
#   templates.host        - `nix flake init -t <core>#host`
{
  inputs,
  lib,
  ...
}: let
  # den's `flake.denful` export strips `__functor` from aspects, which would
  # break callable aspects such as `ry.charger { ... }`. Hosts therefore
  # re-evaluate the aspect *modules* instead of consuming exported data.
  coreModule = {
    imports = [
      (inputs.import-tree ./../core)
      ./_flake-file-stub.nix
    ];
  };

  mkHost = {
    # The host flake's own inputs. Core's inputs are merged underneath, so a
    # host flake only has to declare `core` (plus anything host-specific).
    inputs,
    name,
    system,
    # Each user gets `ry.users.<name>` as its aspect.
    users ? ["ryder"],
    # Host facts: typed options from modules/core/schema.nix plus free-form.
    facts ? {},
    # ry: [ ry.desktop ry.nvidia ... ]
    aspects ? (_: []),
    # Extra den aspect for this host: nixos / homeManager / includes / provides.
    aspect ? {},
    # Extra flake-parts modules, for anything mkHost does not cover.
    modules ? [],
    # Where `nh` (and the shell aliases built on it) find this host's flake.
    flakePath ? "/home/${lib.head users}/nixos-config",
  }: let
    hostInputs = inputs;
    # flake-parts derives `inputs'` (and so `pkgs`) from `self.inputs`, not
    # from the `inputs` it is handed, so the host's `self` gets core's inputs
    # merged into its own as well.
    hostSelf = hostInputs.self // {inputs = coreInputs // hostInputs.self.inputs;};
    allInputs = coreInputs // hostInputs // {self = hostSelf;};
  in
    allInputs.flake-parts.lib.mkFlake {inputs = allInputs;} ({
      ry,
      den,
      ...
    }: {
      imports = [coreModule] ++ modules;
      systems = [system];

      den.hosts.${system}.${name} =
        facts
        // {
          inherit flakePath;
          users = lib.genAttrs users (_: {});
        };

      den.aspects =
        lib.genAttrs users (u: {includes = [ry.users.${u}];})
        // {
          ${name} =
            aspect
            // {
              includes = (aspect.includes or []) ++ aspects ry;
            };
        };

      # `nix run .#<host> -- switch`
      perSystem = {pkgs, ...}: {
        packages = den.lib.nh.denPackages {fromFlake = true;} pkgs;
      };
    });

  coreInputs = builtins.removeAttrs inputs ["self"];
in {
  flake = {
    flakeModules.default = coreModule;
    lib = {inherit mkHost;};
    templates.host = {
      path = ./../../templates/host;
      description = "A host flake built on the core configuration";
    };
  };
}
