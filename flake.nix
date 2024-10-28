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
    });
  };
}
