{
  # Every _scripts/<name>.sh becomes a `<name>` command on PATH. Each is
  # wrapped as bash, so the file's own shebang is only a comment.
  ry.scripts.homeManager = {
    pkgs,
    lib,
    ...
  }: {
    home.packages =
      lib.mapAttrsToList
      (file: _:
        pkgs.writeShellScriptBin
        (lib.removeSuffix ".sh" file)
        (builtins.readFile (./_scripts + "/${file}")))
      (lib.filterAttrs
        (file: type: type == "regular" && lib.hasSuffix ".sh" file)
        (builtins.readDir ./_scripts));
  };
}
