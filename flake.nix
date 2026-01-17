{
  description = "Nix flake for btca (Better Context)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    let
      overlay = final: prev: {
        btca = final.callPackage ./package.nix { };
      };
    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
      in
      {
        packages = {
          default = pkgs.myapp;
          btca = pkgs.btca;
        };

        apps = {
          default = {
            type = "app";
            program = "${pkgs.myapp}/bin/myapp";
            meta.description = "REPLACE WITH YOUR APP DESCRIPTION";
          };
          myapp = {
            type = "app";
            program = "${pkgs.myapp}/bin/myapp";
            meta.description = "REPLACE WITH YOUR APP DESCRIPTION";
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nixpkgs-fmt
            nix-prefetch
            cachix
            gh
            jq
          ];
        };

        formatter = pkgs.nixpkgs-fmt;
      }
    )
    // {
      overlays.default = overlay;
    };
}
