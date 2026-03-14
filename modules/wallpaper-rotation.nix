# =============================================================================
# Wallpaper Rotation — Home Manager Module
# =============================================================================
# Cross-platform random wallpaper rotation with configurable collections.
#
#   macOS:  launchd agent using osascript
#   NixOS:  systemd user timer using plasma-apply-wallpaperimage (KDE)
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
      plasma-apply-wallpaperimage "$wall" 2>/dev/null || true
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
