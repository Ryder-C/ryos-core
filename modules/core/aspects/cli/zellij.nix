{
  ry.zellij.homeManager = {
    programs.zellij = {
      enable = true;
      settings = {
        session_serialization = false;
        default_shell = "fish";
      };
    };
    home.shellAliases = {
      za = "zellij attach (zellij ls | fzf --ansi | cut -d' ' -f1)";
      zj = "zellij -s (basename (pwd))";
    };
  };
}
