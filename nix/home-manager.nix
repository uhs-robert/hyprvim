{ self }:

{ config, lib, pkgs, ... }:

let
  cfg = config.programs.hyprvim;
in
{
  options.programs.hyprvim = {
    enable = lib.mkEnableOption "HyprVim";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      description = "The HyprVim package to use.";
    };

    whichKey.enable = lib.mkEnableOption "HyprVim WhichKey HUD dependencies";
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      [ pkgs.wl-clipboard ]
      ++ lib.optionals cfg.whichKey.enable [
        pkgs.eww
        pkgs.jq
        pkgs.socat
        pkgs.lua
      ];

    home.file.".config/hypr/lua/plugins/hyprvim".source =
      "${cfg.package}/share/hyprvim";
  };
}
