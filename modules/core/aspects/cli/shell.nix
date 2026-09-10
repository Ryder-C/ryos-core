{
  ry.shell.homeManager = {pkgs, ...}: let
    jj-starship = "${pkgs.jj-starship}/bin/jj-starship";
  in {
    programs = {
      fish = {
        enable = true;

        shellInit = ''
          # EDITOR/VISUAL come from home.sessionVariables (ry.editor).
          set -gx FISH_CONFIG_FILE ~/.config/fish/config.fish
          set -gx fish_greeting ""
        '';

        functions = {
          # nh reads NH_FLAKE (programs.nh.flake), so no path plumbing here.
          cdnix = ''
            cd $NH_FLAKE
            nvim
          '';

          nsu = ''
            nh os switch --update
            nix-store --optimise
          '';

          gcma = ''
            git add --all
            git commit -m $argv
          '';
        };

        shellAliases = {
          c = "clear";
          l = "ls";
          ll = "ls -l";
          cd = "z";
          open = "xdg-open";

          # Nix
          nix-shell = "nix-shell --run fish";
          nix-clean = "nh clean all";
          ns = "nh os switch";
          nst = "nh os test";
          nsb = "nh os boot";

          # Git
          ga = "git add";
          gaa = "git add --all";
          gs = "git status";
          gb = "git branch";
          gm = "git merge";
          gpl = "git pull";
          gplo = "git pull origin";
          gps = "git push";
          gpst = "git push --follow-tags";
          gpso = "git push origin";
          gc = "git commit";
          gcm = "git commit -m";
          gtag = "git tag -ma";
          gch = "git checkout";
          gchb = "git checkout -b";
          gcoe = "git config user.email";
          gcon = "git config user.name";

          # jj
          jjc = "jj commit";
          jje = "jj edit";
          jjd = "jj diff";
          jjds = "jj desc";
          jjl = "jj log";
          jjlb = "jj log -r 'fork_point(bookmarks())::'";
          jjn = "jj new";
          jjgf = "jj git fetch";
          jjgp = "jj git push";
          jjbt = "jj bookmark track";
          jjbm = "jj bookmark move";
          jjbs = "jj bookmark set";
          jjsq = "jj squash";
        };

        plugins = [
          {
            name = "fzf";
            inherit (pkgs.fishPlugins.fzf) src;
          }
        ];
      };

      carapace = {
        enable = true;
        enableFishIntegration = true;
      };

      zoxide = {
        enable = true;
        enableFishIntegration = true;
      };

      starship = {
        enable = true;
        presets = ["nerd-font-symbols"];
        settings = {
          directory = {
            format = "[ ](bold #89b4fa)[ $path ]($style)";
            style = "bold #b4befe";
          };
          character = {
            success_symbol = "[ ](bold #89b4fa)[ ➜](bold green)";
            error_symbol = "[ ](bold #89b4fa)[ ➜](bold red)";
          };
          cmd_duration = {
            format = "[󰔛 $duration]($style)";
            disabled = false;
            style = "bg:none fg:#f9e2af";
            show_notifications = false;
            min_time_to_notify = 60000;
          };
          custom.jj = {
            when = "${jj-starship} detect";
            shell = [jj-starship];
            format = "$output ";
          };
          git_branch.disabled = true;
          git_commit.disabled = true;
          git_status.disabled = true;
        };
      };
    };
  };
}
