{
  description = "HyprVim - Vim keybind system for Hyprland";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;
    in {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };

          hyprvim = pkgs.stdenvNoCC.mkDerivation {
            pname = "hyprvim";
            version = "unstable";

            src = self;

            dontConfigure = true;
            dontBuild = true;

            installPhase = ''
              runHook preInstall

              mkdir -p $out/share/hyprvim
              cp -r . $out/share/hyprvim/

              runHook postInstall
            '';

            meta = {
              description = "Vim keybind system for Hyprland";
              homepage = "https://github.com/uhs-robert/hyprvim";
              license = pkgs.lib.licenses.mit;
              platforms = pkgs.lib.platforms.linux;
            };
          };
        in {
          inherit hyprvim;
          default = hyprvim;
        });

      homeManagerModules.default = import ./nix/home-manager.nix {
        inherit self;
      };
    };
}
