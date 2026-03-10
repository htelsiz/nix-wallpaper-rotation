# nix-wallpaper-rotation

Cross-platform random wallpaper rotation for NixOS and macOS via Home Manager.

Ships with [Catppuccin Mocha](https://github.com/orangci/walls-catppuccin-mocha) (330 wallpapers) by default. Bring your own collections too.

## Install

Add the flake input and import the module:

```nix
# flake.nix
{
  inputs.wallpaper-rotation.url = "https://flakehub.com/f/htelsiz/nix-wallpaper-rotation/*.tar.gz";

  outputs = { self, nixpkgs, home-manager, wallpaper-rotation, ... }: {
    # In your Home Manager config:
    homeConfigurations."user" = home-manager.lib.homeManagerConfiguration {
      modules = [
        wallpaper-rotation.homeManagerModules.default
        {
          services.wallpaper-rotation.enable = true;
        }
      ];
    };
  };
}
```

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `services.wallpaper-rotation.enable` | bool | `false` | Enable wallpaper rotation |
| `services.wallpaper-rotation.interval` | int | `900` | Rotation interval in seconds |
| `services.wallpaper-rotation.collections` | list of packages | Catppuccin Mocha | Wallpaper collection derivations |

## Custom collections

```nix
services.wallpaper-rotation = {
  enable = true;
  interval = 1800; # 30 minutes
  collections = [
    (pkgs.fetchFromGitHub {
      owner = "orangci";
      repo = "walls-catppuccin-mocha";
      rev = "7bfdf10d16ad3a689f9f0cf3a0930da3d1a245a8";
      hash = "sha256-N+MZHSRcwOldS5Ai8B3YfKquKs9oeUW/GkV1iKM5+i8=";
    })
    (pkgs.fetchFromGitHub {
      owner = "iQuickDev";
      repo = "catppuccin-wallpapers";
      rev = "main";
      hash = "sha256-ABCDEF..."; # nix-prefetch-url --unpack
    })
  ];
};
```

## Platforms

- **macOS** — launchd agent, sets wallpaper via osascript across all desktops/spaces
- **NixOS/KDE** — systemd user timer, sets wallpaper via `plasma-apply-wallpaperimage`

## Manual trigger

```bash
# macOS
launchctl kickstart -k gui/$(id -u)/org.nixos.wallpaper-rotation

# NixOS
systemctl --user start wallpaper-rotation.service
```
