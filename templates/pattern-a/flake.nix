{
  description = "Nix flake for myapp - REPLACE WITH YOUR DESCRIPTION";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          # REPLACE: Remove if your package is MIT/Apache licensed
          config.allowUnfree = true;
        };
        inherit (pkgs) stdenv;
        myapp = pkgs.callPackage ./package.nix { };

        # ============================================================
        # OPTIONAL: Factory function for customization
        # ============================================================
        # This pattern is useful for applications with plugin/extension systems
        # or user-configurable settings. Delete if not applicable.
        #
        # Usage example:
        #   myappWithExtensions ["extension-id"] { "setting.key" = "value"; }
        #
        # myappWithExtensions =
        #   extensions: settings:
        #   let
        #     settingsArgs =
        #       if settings == null then
        #         { settings = null; keybindings = null; }
        #       else if builtins.isAttrs settings && (settings ? settings || settings ? keybindings) then
        #         { settings = settings.settings or null; keybindings = settings.keybindings or null; }
        #       else
        #         { settings = settings; keybindings = null; };
        #   in
        #   pkgs.callPackage ./package.nix {
        #     inherit extensions;
        #     userSettings = settingsArgs.settings;
        #     userKeybindings = settingsArgs.keybindings;
        #   };
        # ============================================================
      in
      {
        packages = {
          inherit myapp;
          default = myapp;
        };

        apps = {
          myapp = {
            type = "app";
            program = "${myapp}/bin/myapp";
            meta.description = "REPLACE WITH YOUR APP DESCRIPTION";
          };
          default = self.apps.${system}.myapp;
        };

        # ============================================================
        # OPTIONAL: Export lib with factory function
        # ============================================================
        # Uncomment if using the factory function above
        #
        # lib = {
        #   inherit myappWithExtensions;
        # };
        # ============================================================

        formatter = pkgs.nixpkgs-fmt;

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nixpkgs-fmt
            nix-prefetch
            cachix
            gh
            jq
          ];
        };

        # ============================================================
        # OPTIONAL: Flake checks
        # ============================================================
        # These checks validate your package builds correctly.
        # Customize based on your application's needs.
        checks =
          let
            # Helper to find wrapper script path
            # Adjust based on your wrapper location
            findWrapper = pkg: "${pkg}/bin/myapp";
          in
          {
            # Basic build check
            build = myapp;

            # Wrapper syntax check
            wrapper-syntax = pkgs.runCommand "myapp-wrapper-syntax-check" { } ''
              ${pkgs.bash}/bin/bash -n ${findWrapper myapp}
              echo "Wrapper script syntax OK" > $out
            '';

            # ============================================================
            # OPTIONAL: Additional checks for extensions/settings
            # ============================================================
            # Uncomment if using the factory function
            #
            # with-extensions =
            #   let
            #     myappWithExt = myappWithExtensions [ "sample.extension" ] null;
            #   in
            #   pkgs.runCommand "myapp-with-extensions-check" { } ''
            #     test -x ${myappWithExt}/bin/myapp
            #     ${pkgs.bash}/bin/bash -n ${findWrapper myappWithExt}
            #     echo "Build with extensions OK" > $out
            #   '';
            #
            # with-settings =
            #   let
            #     myappWithSettings = myappWithExtensions [ ] { "some.setting" = true; };
            #   in
            #   pkgs.runCommand "myapp-with-settings-check" { } ''
            #     test -x ${myappWithSettings}/bin/myapp
            #     ${pkgs.bash}/bin/bash -n ${findWrapper myappWithSettings}
            #     echo "Build with settings OK" > $out
            #   '';
            # ============================================================
          };
      }
    )
    // {
      overlays.default = final: prev: {
        myapp-nix = self.packages.${prev.system}.myapp;
      };
    };
}
