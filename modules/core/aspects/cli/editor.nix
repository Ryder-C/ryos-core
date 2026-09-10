{inputs, ...}: {
  flake-file.inputs.nixvim.url = "github:Ryder-C/nixvim";

  # `ry.editor` = neovim + helix + micro with EDITOR=nvim.
  # Pick parts with `ry.editor.<name>` (also zed, vscode).
  ry.editor = {config, ...}: {
    includes = [
      config.provides.neovim
      config.provides.helix
      config.provides.micro
    ];

    homeManager.home.sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };

    provides = {
      neovim.homeManager = {pkgs, ...}: {
        home.packages = [inputs.nixvim.packages.${pkgs.stdenv.hostPlatform.system}.default];
      };

      micro.homeManager = {
        programs.micro = {
          enable = true;
          settings = {
            "*.nix".tabsize = 2;
            "*.ml".tabsize = 2;
            "*.sh".tabsize = 2;
            tabstospaces = true;
            tabsize = 4;
          };
        };
        home.shellAliases.nano = "micro";
        xdg.configFile."micro/bindings.json".text = builtins.toJSON {
          "Ctrl-Up" = "CursorUp,CursorUp,CursorUp,CursorUp,CursorUp";
          "Ctrl-Down" = "CursorDown,CursorDown,CursorDown,CursorDown,CursorDown";
          "Ctrl-Backspace" = "DeleteWordLeft";
          "Ctrl-Delete" = "DeleteWordRight";
          "CtrlShiftUp" = "ScrollUp,ScrollUp,ScrollUp,ScrollUp,ScrollUp";
          "CtrlShiftDown" = "ScrollDown,ScrollDown,ScrollDown,ScrollDown,ScrollDown";
        };
      };

      helix.homeManager = {pkgs, ...}: {
        programs.helix = {
          enable = true;
          extraPackages = with pkgs; [
            nil
            tinymist
            rust-analyzer-unwrapped
            typstyle
            lldb_19
          ];
          settings = {
            editor.cursor-shape = {
              normal = "block";
              insert = "bar";
              select = "underline";
            };

            # Colemak-DH mappings
            keys = let
              motion = {
                n = "move_char_left";
                e = "move_line_down";
                i = "move_line_up";
                o = "move_char_right";
                h = "insert_mode";
                H = "insert_at_line_start";
                l = "open_below";
                L = "open_above";
                k = "move_next_word_end";
                K = "move_next_long_word_end";
                j = "search_next";
                J = "search_prev";
              };
            in {
              normal =
                motion
                // {
                  g = {
                    n = "goto_line_start";
                    o = "goto_line_end";
                  };
                  space.w = {
                    n = "jump_view_left";
                    e = "jump_view_down";
                    i = "jump_view_up";
                    o = "jump_view_right";
                  };
                  C-w = {
                    n = "jump_view_left";
                    e = "jump_view_down";
                    E = "join_selections";
                    "A-E" = "join_selections_space";
                    i = "jump_view_up";
                    I = "keep_selections";
                    "A-I" = "remove_selections";
                    o = "jump_view_right";
                  };
                  z = {
                    e = "scroll_down";
                    i = "scroll_up";
                  };
                  Z = {
                    e = "scroll_down";
                    i = "scroll_up";
                  };
                };
              insert."A-x" = "normal_mode";
              select = motion;
            };
          };

          languages = {
            language-server.tinymist = {
              command = "tinymist";
              config = {
                exportPdf = "onType";
                outputPath = "$root/out/$name";
              };
            };
            language = [
              {
                name = "rust";
                auto-format = true;
              }
              {
                name = "nix";
                auto-format = true;
                formatter = {
                  command = "alejandra";
                  args = ["-q"];
                };
              }
              {
                name = "typst";
                auto-format = true;
                formatter = {
                  command = "typstyle";
                  args = ["-i"];
                };
                language-servers = ["tinymist"];
                soft-wrap.enable = true;
              }
            ];
          };
        };
      };

      zed.homeManager.programs.zed-editor.enable = true;

      vscode.homeManager = {pkgs, ...}: {
        home.packages = [pkgs.vscode];
      };
    };
  };
}
