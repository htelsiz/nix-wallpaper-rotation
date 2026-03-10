{
  description = "Cross-platform wallpaper rotation for NixOS and macOS via Home Manager";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
  {
    homeManagerModules = {
      wallpaper-rotation = import ./modules/wallpaper-rotation.nix;
      default = self.homeManagerModules.wallpaper-rotation;
    };
  };
}
