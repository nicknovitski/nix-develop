{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {
    self,
    nixpkgs,
  }: let
    eachSystem = f:
      nixpkgs.lib.genAttrs nixpkgs.lib.platforms.unix (system:
        f {
          inherit system;
          pkgs = nixpkgs.legacyPackages.${system};
        });
  in {
    formatter = eachSystem ({pkgs, ...}: pkgs.alejandra);
    packages = eachSystem ({pkgs, ...}: {
      default = pkgs.writeShellApplication {
        name = "nix-develop-gha";
        runtimeInputs = [pkgs.gnugrep pkgs.openssl.bin pkgs.coreutils];
        text = builtins.readFile ./nix-develop-gha.sh;
      };
    });
    devShells = eachSystem ({pkgs, ...}: {
      default = pkgs.mkShell {
        packages = [pkgs.shfmt pkgs.shellcheck pkgs.actionlint];
      };
      notDefault = pkgs.mkShell {
        packages = [pkgs.cowsay];
      };
    });
    checks = eachSystem ({
      pkgs,
      system,
      ...
    }: {
      package = self.packages.${system}.default;
      actionlint = let
        fs = pkgs.lib.fileset;
      in
        pkgs.runCommand "lint-actions" {
          nativeBuildInputs = [
            pkgs.actionlint
            pkgs.git
            pkgs.shellcheck # actionlint uses this to check `run:` stanzas
          ];
          src = fs.toSource {
            root = ./.;
            fileset = fs.unions [./.github/workflows];
          };
        }
        ''
          set -euo pipefail
          cp -R $src src-copy
          chmod -R +w src-copy
          cd src-copy
          git init --quiet
          actionlint -color
          touch $out
        '';
    });
  };
}
