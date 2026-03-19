# =============================================================================
# Wallpaper Rotation — Home Manager Module
# =============================================================================
# Cross-platform random wallpaper rotation with configurable collections.
#
#   macOS:    launchd agent using osascript
#   KDE:      plasma-apply-wallpaperimage
#   Noctalia: noctalia-shell IPC (niri/Quickshell-based)
#   GNOME:    gsettings
#   Sway:     swaymsg output * bg <path> fill
#   Hyprland: hyprctl hyprpaper wallpaper
#   Generic:  swaybg / feh fallback
#
# Usage in your flake:
#   imports = [ nix-wallpaper-rotation.homeManagerModules.default ];
#   services.wallpaper-rotation.enable = true;
# =============================================================================

{ config, lib, pkgs, ... }:

let
  cfg = config.services.wallpaper-rotation;
  isDarwin = pkgs.stdenv.isDarwin;

  # Default wallpaper collection: Catppuccin Mocha (330 images)
  defaultCollection = pkgs.fetchFromGitHub {
    owner = "orangci";
    repo = "walls-catppuccin-mocha";
    rev = "7bfdf10d16ad3a689f9f0cf3a0930da3d1a245a8";
    hash = "sha256-N+MZHSRcwOldS5Ai8B3YfKquKs9oeUW/GkV1iKM5+i8=";
  };

  wallDir = "$HOME/.local/share/wallpapers";

  darwinScript = lib.getExe (pkgs.writeShellApplication {
    name = "wallpaper-rotate";
    runtimeInputs = with pkgs; [ findutils coreutils ];
    text = ''
      [ -d "${wallDir}" ] || exit 0
      wall=$(find -L "${wallDir}" -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \) | shuf -n1)
      [ -n "$wall" ] || exit 0
      /usr/bin/osascript -e "tell application \"System Events\" to set picture of every desktop to \"$wall\""
    '';
  });

  linuxScript = lib.getExe (pkgs.writeShellApplication {
    name = "wallpaper-rotate";
    runtimeInputs = with pkgs; [ findutils coreutils ];
    text = ''
      wall=$(find -L "${wallDir}" -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \) | shuf -n1)
      [ -n "$wall" ] || exit 0

      desktop="''${XDG_CURRENT_DESKTOP:-}"

      # KDE Plasma
      if [ "$desktop" = "KDE" ] && command -v plasma-apply-wallpaperimage &>/dev/null; then
        plasma-apply-wallpaperimage "$wall" 2>/dev/null
        exit 0
      fi

      # Noctalia Shell (niri / Quickshell-based Wayland shell)
      if command -v noctalia-shell &>/dev/null && pgrep -x quickshell &>/dev/null; then
        noctalia-shell ipc call wallpaper set "$wall" ""
        exit 0
      fi

      # GNOME
      if [ "$desktop" = "GNOME" ] && command -v gsettings &>/dev/null; then
        gsettings set org.gnome.desktop.background picture-uri "file://$wall"
        gsettings set org.gnome.desktop.background picture-uri-dark "file://$wall"
        exit 0
      fi

      # Sway
      if [ "$desktop" = "sway" ] || [ "''${SWAYSOCK:-}" != "" ]; then
        if command -v swaymsg &>/dev/null; then
          swaymsg output '*' bg "$wall" fill
          exit 0
        fi
      fi

      # Hyprland
      if [ "$desktop" = "Hyprland" ] && command -v hyprctl &>/dev/null; then
        hyprctl hyprpaper wallpaper ",$wall"
        exit 0
      fi

      # Fallback: swaybg (kills previous instance, starts new one)
      if command -v swaybg &>/dev/null; then
        pkill swaybg 2>/dev/null || true
        swaybg -i "$wall" -m fill &
        disown
        exit 0
      fi

      # Fallback: feh (X11)
      if command -v feh &>/dev/null; then
        feh --bg-fill "$wall"
        exit 0
      fi

      echo "wallpaper-rotate: no supported wallpaper setter found" >&2
      exit 1
    '';
  });
in
{
  options.services.wallpaper-rotation = {
    enable = lib.mkEnableOption "random wallpaper rotation";

    interval = lib.mkOption {
      type = lib.types.int;
      default = 900;
      description = "Rotation interval in seconds (default: 900 = 15 minutes).";
    };

    collections = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ defaultCollection ];
      description = "List of wallpaper collection derivations to symlink.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Symlink wallpaper collections into ~/.local/share/wallpapers/
    home.file = lib.listToAttrs (lib.imap0 (i: coll: {
      name = ".local/share/wallpapers/collection-${toString i}";
      value = { source = coll; };
    }) cfg.collections);

    # macOS: launchd agent
    launchd.agents.wallpaper-rotation = lib.mkIf isDarwin {
      enable = true;
      config = {
        ProgramArguments = [ darwinScript ];
        RunAtLoad = true;
        StartInterval = cfg.interval;
      };
    };

    # Linux: systemd user service + timer
    systemd.user.services.wallpaper-rotation = lib.mkIf (!isDarwin) {
      Unit = {
        Description = "Random wallpaper rotation";
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = linuxScript;
      };
    };

    systemd.user.timers.wallpaper-rotation = lib.mkIf (!isDarwin) {
      Unit.Description = "Random wallpaper rotation timer";
      Timer = {
        OnStartupSec = "10";
        OnUnitActiveSec = "${toString cfg.interval}";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
