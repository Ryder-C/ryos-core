let
  rylib = import ../../_lib.nix;
in {
  # Sunshine, the host half of Moonlight game streaming
  # (github:LizardByte/Sunshine). Pair clients and add apps from the web UI on
  # https://localhost:47990; the stream itself follows the graphical session,
  # so the seat has to be logged in.
  ry.sunshine = {
    # The virtual gamepad/keyboard/mouse Sunshine creates for the client go
    # through /dev/uinput.
    includes = [(rylib.groups ["input" "uinput"])];

    nixos = {pkgs, ...}: {
      services.sunshine = {
        enable = true;
        openFirewall = true;

        # NVENC needs two things that nixpkgs does not give it by default.
        #
        # 1. cudaSupport. Every capture backend gates the nvenc path behind
        #    `#ifdef SUNSHINE_BUILD_CUDA` (wlgrab.cpp:276, kmsgrab.cpp:1247,
        #    pipewire.cpp:893); nixpkgs passes SUNSHINE_ENABLE_CUDA=OFF without
        #    it. Sunshine then asks for a CUDA frame, falls through to a plain
        #    software encode device and dies in sws_scale_frame -- logged as the
        #    very unhelpful "Couldn't scale frame: Invalid argument", after which
        #    it quietly settles on libx264 at ~20ms of host latency per frame.
        #    cudaPackages has to be passed too: it defaults to `{}`, so
        #    cudaSupport alone fails on cudaPackages.backendStdenv.
        #
        # 2. /run/opengl-driver/lib on the RUNPATH, so the dlopen of
        #    libnvidia-encode.so.1 resolves. (Symptom when it doesn't: "Cannot
        #    load libnvidia-encode.so.1", plus a bogus "minimum required driver
        #    is 570.0" -- ffmpeg's fallback text for any dlopen miss, not a real
        #    version check.) cudaSupport happens to cover this as well, via the
        #    autoAddDriverRunpath hook the CUDA setup hooks pull in; it is the
        #    reason no explicit addDriverRunpath is needed here. Note that
        #    LD_LIBRARY_PATH would not have worked: capSysAdmin below routes
        #    ExecStart through security.wrappers, and NixOS's wrapper.c unsets
        #    every name in glibc's UNSECURE_ENVVARS before exec.
        package = pkgs.sunshine.override {
          cudaSupport = true;
          inherit (pkgs) cudaPackages;
        };

        # Capture goes through wlgrab (`capture = wlr`) against umbriel's
        # virtual output, see homeManager below; it needs no privileges.
        # CAP_SYS_ADMIN is kept only for the DRM/KMS fallback.
        capSysAdmin = true;

        # Don't start with the graphical session: this only drops the
        # graphical-session.target wantedBy, so the user unit is still there and
        # `systemctl --user start sunshine` brings it up when a stream is
        # actually wanted. It stays partOf graphical-session.target either way,
        # so it still goes down with the session.
        autoStart = false;

        # `settings` and `applications` are deliberately left unset: the nixpkgs
        # module only passes a config file once one of them is set, and from then
        # on the web UI can no longer save anything -- every app and every
        # resolution tweak would have to come back through here.
      };
    };

    # Stream a virtual umbriel output sized to the client instead of a
    # physical monitor. Sunshine's own config stays in the web UI, so these
    # three settings go there (Advanced / Audio-Video / General):
    #   capture         = wlr
    #   output_name     = sunshine
    #   global_prep_cmd = [{"do":"/etc/profiles/per-user/<user>/bin/sunshine-umbriel-output create",
    #                       "undo":"/etc/profiles/per-user/<user>/bin/sunshine-umbriel-output remove"}]
    homeManager = {
      config,
      pkgs,
      ...
    }: {
      imports = [
        (rylib.whenUmbriel {
          home.packages = [
            (pkgs.writeShellApplication {
              name = "sunshine-umbriel-output";
              runtimeInputs = [config.programs.umbriel.package pkgs.jq pkgs.coreutils];
              # Adapted from umbriel's docs/user/streaming.md.
              text = ''
                name=sunshine

                case "''${1:-}" in
                  create)
                    umbriel output-destroy "$name" >/dev/null 2>&1 || true
                    umbriel output-create "$name" \
                      "''${SUNSHINE_CLIENT_WIDTH:-1920}x''${SUNSHINE_CLIENT_HEIGHT:-1080}@''${SUNSHINE_CLIENT_FPS:-60}" >/dev/null
                    ;;
                  remove)
                    # Give windows the app's undo command is closing up to 5s to
                    # go, so they don't flash onto a physical monitor.
                    i=0
                    while [ "$i" -lt 25 ]; do
                      left="$(umbriel windows --json |
                        jq --arg out "$name:" '[.[] | select(.workspace | startswith($out))] | length')"
                      [ "$left" = 0 ] && break
                      sleep 0.2
                      i=$((i + 1))
                    done
                    # Move the rest explicitly: an evacuated window remembers the
                    # output as home and would jump onto the next stream.
                    read -r target_ws target_out < <(umbriel workspaces --json |
                      jq -r --arg out "$name" '[.[] | select(.output != $out and .active)]
                        | (map(select(.focused)) + .) | first // empty | "\(.name) \(.output)"') || true
                    for id in $(umbriel windows --json |
                      jq -r --arg out "$name:" '.[] | select(.workspace | startswith($out)) | .id'); do
                      [ -n "''${target_ws:-}" ] || break
                      umbriel msg window-focus "$id"
                      umbriel msg window-move-to-workspace-silent --name "$target_ws" --output "$target_out"
                    done
                    umbriel output-destroy "$name" >/dev/null 2>&1 || true
                    ;;
                  *)
                    echo "usage: sunshine-umbriel-output create|remove" >&2
                    exit 2
                    ;;
                esac
              '';
            })
          ];

          # Send Big Picture and Proton games to the stream. With no stream
          # running the output doesn't exist and default_output is ignored.
          # For a Wine-Wayland game that still sizes itself for a physical
          # monitor, add `WAYLANDDRV_PRIMARY_MONITOR=sunshine %command%`.
          programs.umbriel.settings.window_rule = [
            {
              match.app_id = "^steam$";
              match.title = "[Bb]ig [Pp]icture";
              default_output = "sunshine";
              default_fullscreen = true;
            }
            {
              match.app_id = "^steam_app_";
              default_output = "sunshine";
            }
          ];
        })
      ];
    };
  };
}
