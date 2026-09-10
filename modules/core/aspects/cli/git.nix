{
  ry.git.homeManager = {pkgs, ...}: {
    home.packages = with pkgs; [
      gh
      git-lfs
      difftastic
      jjui
    ];

    programs = {
      git = {
        enable = true;
        settings = {
          user = {
            name = "Ryder Casazza";
            email = "rydercasazza@gmail.com";
          };
          init.defaultBranch = "main";
          credential.helper = "store";
        };
      };

      jujutsu = {
        enable = true;
        settings = {
          user = {
            name = "Ryder Casazza";
            email = "rydercasazza@gmail.com";
          };
          ui = {
            default-command = ["log" "-r" "trunk()::"];
            diff-formatter = ["difft" "--color=always" "$left" "$right"];
          };
          aliases = {
            # After a squash merge, rebase the changes that were stacked on the
            # merged branch back onto trunk.
            sync = ["rebase" "-s" "((roots((((::trunk()):: ~ ::trunk()) & mutable())..(::trunk()))-)+ & mutable()) ~ ::trunk()" "-o" "trunk()"];
          };
        };
      };

      lazygit = {
        enable = true;
        settings.gui = {
          theme = {
            activeBorderColor = ["#cba6f7" "bold"];
            inactiveBorderColor = ["#a6adc8"];
            optionsTextColor = ["#89b4fa"];
            selectedLineBgColor = ["#313244"];
            cherryPickedCommitBgColor = ["#45475a"];
            cherryPickedCommitFgColor = ["#cba6f7"];
            unstagedChangesColor = ["#f38ba8"];
            defaultFgColor = ["#cdd6f4"];
            searchingActiveBorderColor = ["#f9e2af"];
          };
          authorColors."*" = "#b4befe";
        };
      };
    };
  };
}
