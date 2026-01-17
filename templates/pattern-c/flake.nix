{
  description = "Nix flake for myapp - REPLACE WITH YOUR DESCRIPTION";

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
        myapp = final.callPackage ./package.nix { };
      };
    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          # REPLACE: Remove if your upstream app is open source
          config.allowUnfree = true;
          overlays = [ overlay ];
        };
      in
      {
        packages = {
          default = pkgs.myapp;
          myapp = pkgs.myapp;
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
