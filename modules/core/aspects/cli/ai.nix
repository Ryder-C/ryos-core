{inputs, ...}: {
  flake-file.inputs = {
    claude-code.url = "github:sadjow/claude-code-nix";
    humanizer = {
      url = "github:blader/humanizer";
      flake = false;
    };
  };

  # Coding agents and the MCP servers they share. Model providers that only
  # exist on some hosts (ry.ollama) register themselves.
  ry.ai = {
    nixos.nixpkgs.overlays = [
      inputs.claude-code.overlays.default
      # aioboto3/fastmcp installCheck tests fail with "Duplicate 'Server'
      # header" on newer aiohttp; both are pulled in by mcp-nixos.
      (_final: prev: {
        python313 = prev.python313.override {
          packageOverrides = _pyFinal: pyPrev: {
            aioboto3 = pyPrev.aioboto3.overrideAttrs (_: {doInstallCheck = false;});
            fastmcp = pyPrev.fastmcp.overrideAttrs (_: {doInstallCheck = false;});
          };
        };
      })
    ];

    homeManager = {
      config,
      lib,
      pkgs,
      ...
    }: {
      programs = {
        mcp = {
          enable = true;
          servers = {
            nixos.command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
            duckduckgo = {
              command = lib.getExe' pkgs.uv "uvx";
              args = ["duckduckgo-mcp-server"];
            };
          };
        };

        claude-code = {
          enable = true;
          enableMcpIntegration = true;
          package = pkgs.claude-code;
          skills.humanizer = inputs.humanizer.outPath;
          lspServers.rust-analyzer = {
            command = "rust-analyzer";
            extensionToLanguage.".rs" = "rust";
          };
          settings = {
            preferredNotifChannel = "terminal_bell";
            statusLine = {
              type = "command";
              command = "bash ${config.home.homeDirectory}/.claude/statusline-command.sh";
            };
          };
        };

        opencode = {
          enable = true;
          enableMcpIntegration = true;
        };

        pi-coding-agent.enable = true;
      };

      home.file.".claude/statusline-command.sh" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash
          # Claude Code status line, mirroring the Starship Catppuccin Mocha prompt.

          input=$(cat)

          cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
          model=$(echo "$input" | jq -r '.model.display_name // empty')
          used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
          five_hour=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
          seven_day=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

          blue='\033[38;2;137;180;250m'
          lavender='\033[38;2;180;190;254m'
          yellow='\033[38;2;249;226;175m'
          peach='\033[38;2;250;179;135m'
          reset='\033[0m'

          if [ -n "$cwd" ]; then
              home="$HOME"
              short_cwd="''${cwd/#$home/~}"
          else
              short_cwd="?"
          fi

          parts=""
          parts="''${parts}$(printf "''${blue} ''${lavender}''${short_cwd}''${reset}")"

          if [ -n "$model" ]; then
              parts="''${parts}  $(printf "''${blue}''${model}''${reset}")"
          fi

          if [ -n "$used" ]; then
              used_int=$(printf '%.0f' "$used")
              parts="''${parts}  $(printf "''${yellow}ctx:''${used_int}%%''${reset}")"
          fi

          if [ -n "$five_hour" ]; then
              five_int=$(printf '%.0f' "$five_hour")
              parts="''${parts}  $(printf "''${peach}5h:''${five_int}%%''${reset}")"
          fi
          if [ -n "$seven_day" ]; then
              week_int=$(printf '%.0f' "$seven_day")
              parts="''${parts}  $(printf "''${peach}7d:''${week_int}%%''${reset}")"
          fi

          printf "%b" "$parts"
        '';
      };
    };
  };
}
