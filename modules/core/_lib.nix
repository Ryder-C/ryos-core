# Small helpers shared by aspects. Not auto-imported (leading underscore);
# aspects do `let rylib = import ../../_lib.nix; in`.
let
  stripNewline = s:
    if builtins.substring (builtins.stringLength s - 1) 1 s == "\n"
    then builtins.substring 0 (builtins.stringLength s - 1) s
    else s;
in rec {
  # Add `groups` to every user of the host that includes the aspect. den fans a
  # `{ user, ... }` include out per user, and nixos-class content emitted at the
  # user scope lands on the host.
  groups = names: {user, ...}: {
    nixos.users.users.${user.userName}.extraGroups = names;
  };

  # A home-manager module that only applies when `programs.<prog>` is
  # declared, so app aspects can add niri keybinds or noctalia settings without
  # depending on ry.niri / ry.noctalia. Only `config` may depend on `options`:
  # a module whose attribute names depend on `options` is an infinite recursion.
  whenProgram = prog: module: {
    options,
    lib,
    ...
  }: {
    config = lib.optionalAttrs (options.programs ? ${prog}) module;
  };
  whenNiri = whenProgram "niri";
  whenNoctalia = whenProgram "noctalia";

  # Keep only packages that exist for this host's platform, so one app list
  # can serve x86_64 and aarch64 machines. `null` entries (a flake input that
  # has no package for the system) are dropped too.
  availableOn = pkgs: lib:
    builtins.filter (p: p != null && lib.meta.availableOn pkgs.stdenv.hostPlatform p);

  # --- secrets -------------------------------------------------------------
  # Hosts supply instance-local secrets through `facts.secrets.<name>`, as a
  # string or a path. The module arguments `secretFile`/`secretValue`
  # (defaults.nix) wrap these for class modules; the raw forms below are for
  # aspect-level code such as quirk producers, which only have `host`.

  missingSecret = host: name:
    throw ''
      ry: host `${host.name}` needs the secret `${name}`.
      Set `facts.secrets.${name}` (a string or a path) in its flake.
    '';

  hostSecret = host: name: host.secrets.${name} or null;

  # The literal secret.
  secretValue = host: name: let
    v = hostSecret host name;
  in
    if v == null
    then missingSecret host name
    else if builtins.isPath v
    then stripNewline (builtins.readFile v)
    else v;
}
