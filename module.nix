{ self, lib }:

{
  options = {
    programs.btca = {
      enable = lib.mkEnableOption "btca - Better Context AI";

      settings = lib.mkOption {
        type = lib.types.submodule {
          freeformType = lib.types.attrsOf lib.types.anything;
        };
        default = {
          model = "haiku-4-5";
          provider = "anthropic";
          resources = [ ];
        };
        example = lib.literalExample ''
          {
            model = "haiku-4-5";
            provider = "anthropic";
            resources = [
              {
                type = "git";
                name = "tailwind";
                url = "https://github.com/tailwindlabs/tailwindcss";
                branch = "main";
              }
            ];
          }
        '';
        description = ''
          btca configuration. See https://btca.dev/btca.schema.json
        '';
      };
    };
  };

  config =
    {
      config,
      pkgs,
      lib',
      ...
    }:
    let
      cfg = config.programs.btca;
    in
    lib.mkIf cfg.enable {
      xdg.configFile."btca/btca.config.jsonc" = {
        text = builtins.toJSON cfg.settings;
      };

      environment.systemPackages = [
        self.packages.${pkgs.system}.default
      ];
    };
}
