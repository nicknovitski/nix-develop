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
    devShells = eachSystem ({pkgs, ...}: {
      default = pkgs.mkShell {
        packages = [pkgs.shellcheck pkgs.actionlint];
      };
    });
  };
}
