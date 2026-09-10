let
  rylib = import ../../_lib.nix;
in {
  # `ry.gpu-screen-recorder` = the recorder, its setuid capture helper and the
  # GTK front-end. `ry.gpu-screen-recorder.replay` arms noctalia's replay
  # buffer at login (needs ry.noctalia).
  ry.gpu-screen-recorder = {
    nixos.programs.gpu-screen-recorder.enable = true;
    homeManager = {pkgs, ...}: {
      home.packages = [pkgs.gpu-screen-recorder-gtk];
    };

    provides.replay = {
      nixos = let
        # Both portal units ship an empty WantedBy, so nothing has started them
        # at login. The screen_recorder plugin won't arm the replay buffer
        # unless it can see both running (it scans /proc) and never triggers
        # the D-Bus activation that would start them: a deadlock, not a race.
        startWithSession = {
          overrideStrategy = "asDropin";
          wantedBy = ["graphical-session.target"];
        };
      in {
        systemd.user.services = {
          xdg-desktop-portal = startWithSession;
          xdg-desktop-portal-gnome = startWithSession;
        };
      };

      homeManager = {
        config,
        lib,
        pkgs,
        ...
      }: {
        imports = [
          (rylib.whenNoctalia {
            programs.noctalia.settings = {
              bar.main.end = lib.mkBefore ["recorder"];

              plugins.enabled = ["noctalia/screen_recorder"];

              plugin_settings."noctalia/screen_recorder" = {
                replay_enabled = true;
                replay_duration = 60;
                # Reuse the saved xdg-desktop-portal session so the unattended
                # replay-buffer autostart does not raise a screen picker at login.
                restore_portal = true;

                # Four separate audio tracks: 1 game only, 2 Discord, 3 Spotify,
                # 4 mic. Game leads so anything reading only track 1 (Discord,
                # browser previews) gets the game without chat or music.
                #
                # The plugin only ever emits one `-a` flag, and splices
                # audio_source into the command line unquoted, so the extra
                # `-a`s hidden in this value are what produce the extra tracks.
                # The quotes are load-bearing (a bare `|` would be a pipe). If a
                # plugin update starts quoting or validating audio_source this
                # silently collapses to one track; check the running process
                # args after a noctalia bump.
                audio_source = ''"app-inverse:Discord|app-inverse:Spotify" -a app:Discord -a app:Spotify -a default_input'';
              };

              widget.recorder = {
                type = "noctalia/screen_recorder:recorder";
                # Left click normally toggles a full recording; rebind it so the
                # only thing the bar icon does is flush the replay buffer to disk.
                actions.left = "plugin noctalia/screen_recorder:service all replay-save";
              };

              # Arm the replay buffer for the session. Poll for the process
              # rather than trusting msg's exit status: msg succeeds as soon as
              # the plugin loads, but replay-start still fails silently if the
              # portal isn't up yet. replay-start is a no-op once the recorder
              # is running, so retries are free.
              hooks.started = let
                noctalia = lib.getExe config.programs.noctalia.package;
              in "i=0; while [ $i -lt 30 ]; do pgrep -f 'gpu-screen-recorde[r].*-r ' >/dev/null 2>&1 && break; ${noctalia} msg plugin noctalia/screen_recorder:service all replay-start >/dev/null 2>&1; i=$((i+1)); sleep 2; done";
            };
          })
        ];

        # Kill the replay buffer at logout ourselves. It lives in noctalia's
        # transient scope, which systemd stops in the same instant as niri and
        # pipewire; gpu-screen-recorder's SIGTERM handler only sets a flag its
        # capture loop polls, and that loop is already blocked on a capture
        # source that has gone away. So it hangs until the 90s stop timeout
        # SIGKILLs it; we just send that SIGKILL up front. The ring buffer is
        # RAM-only and dropped at session end anyway.
        #
        # `recorde[r]` stops pkill matching the ExecStop script itself. The
        # trailing space in `-r ` is what tells a replay buffer apart from a
        # plain recording, so the quotes are load-bearing.
        systemd.user.services.gpu-screen-recorder-replay-stop = {
          Unit = {
            Description = "Stop the gpu-screen-recorder replay buffer at session exit";
            After = ["graphical-session.target"];
            PartOf = ["graphical-session.target"];
          };
          Service = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${pkgs.coreutils}/bin/true";
            # `|| true` because pkill exits 1 when nothing matched, which is
            # normal for a session that never armed the buffer.
            ExecStop = pkgs.writeShellScript "stop-gpu-screen-recorder-replay" ''
              ${pkgs.procps}/bin/pkill -KILL -f 'gpu-screen-recorde[r].*-r ' || true
            '';
          };
          Install.WantedBy = ["graphical-session.target"];
        };
      };
    };
  };
}
