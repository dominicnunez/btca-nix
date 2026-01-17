# btca-nix

Nix flake for [btca](https://btca.dev) (Better Context) - a CLI tool that helps AI agents get up-to-date context on libraries/technologies by searching actual source code.

## Quick Install

Run btca directly without installation:

```bash
nix run github:dominicnunez/btca-nix
```

This package includes sensible defaults so btca works out of the box:

| Setting | Default |
|---------|---------|
| `model` | `claude-haiku-4-5` |
| `provider` | `opencode` |
| `resources` | `[]` |

## Profile Install

Install btca to your user profile:

```bash
nix profile install github:dominicnunez/btca-nix
```

## Flake Integration

Add btca to your flake-based configuration:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    btca-nix.url = "github:dominicnunez/btca-nix";
  };

  outputs = { self, nixpkgs, btca-nix, ... }: {
    # Option 1: Use the overlay
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        {
          nixpkgs.overlays = [ btca-nix.overlays.default ];
          environment.systemPackages = [ pkgs.btca ];
        }
      ];
    };

    # Option 2: Use the package directly
    # btca-nix.packages.x86_64-linux.btca
  };
}
```

## Declarative Configuration

btca can take Nix-provided defaults via the `userSettings` argument, which are merged into the runtime config at `~/.config/btca/btca.config.jsonc`.

```nix
{
  outputs = { self, nixpkgs, btca-nix, ... }: {
    packages.x86_64-linux.btca = btca-nix.packages.x86_64-linux.btca.override {
      userSettings = {
        provider = "openai";
        model = "gpt-4.1-mini";
      };
    };
  };
}
```

Merge behavior:

- On first run, btca writes the Nix defaults (including the `$schema` field) to `~/.config/btca/btca.config.jsonc`.
- On subsequent runs, Nix defaults are merged into the existing config, but user edits take precedence and user-only keys are preserved.
- The config is only rewritten when the Nix-provided settings change.

## Binary Cache

Speed up builds by using the Cachix binary cache:

```bash
# Install cachix if you haven't already
nix profile install nixpkgs#cachix

# Enable the btca-nix cache
cachix use btca-nix
```

Or add manually to your Nix configuration:

```nix
{
  nix.settings = {
    substituters = [ "https://btca-nix.cachix.org" ];
    trusted-public-keys = [ "btca-nix.cachix.org-1:A4Ftfyl8BCpQ9OpwuHl4ILxLWMpUcyYnXg57ImNNOw0=" ];
  };
}
```

## About btca

btca (Better Context) helps AI agents get up-to-date context on libraries and technologies by searching actual source code. Learn more at [btca.dev](https://btca.dev).
