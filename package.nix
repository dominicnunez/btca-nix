{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  jq,
  writeText,
  userSettings ? { },
}:

let
  # Note: version.json uses a single "hash" instead of per-platform "hashes" because
  # the npm tarball contains all platform binaries in one archive (unlike GitHub releases
  # which typically have separate downloads per platform).
  versionInfo = lib.importJSON ./version.json;
  version = versionInfo.version;
  # Map Nix system to binary asset platform suffix
  platformMap = {
    "x86_64-linux" = "linux-x64";
    "aarch64-linux" = "linux-arm64";
    "x86_64-darwin" = "darwin-x64";
    "aarch64-darwin" = "darwin-arm64";
  };

  isDarwin = stdenv.hostPlatform.isDarwin;
  system = stdenv.hostPlatform.system;
  platform = platformMap.${system} or (throw "Unsupported system: ${system}");
  hash = versionInfo.hash;

  settingsJson = writeText "btca.config.json" (
    builtins.toJSON (
      lib.recursiveUpdate userSettings {
        "$schema" = "https://btca.dev/btca.schema.json";
      }
    )
  );

  # npm registry tarball URL (single tarball contains all platform binaries)
  src = fetchurl {
    url = "https://registry.npmjs.org/btca/-/btca-${version}.tgz";
    inherit hash;
  };

  # Home Manager detection wrapper script
  wrapperScript = ''
    #!/usr/bin/env bash

    # Verbose output (opt-in via BTCA_NIX_VERBOSE=1)
    verbose=''${BTCA_NIX_VERBOSE:-0}

    # Home Manager detection function
    is_home_manager_active() {
      [[ -n "''${HM_SESSION_VARS:-}" ]] ||
      [[ -d "$HOME/.config/home-manager" ]] ||
      [[ -d "/etc/profiles/per-user/$USER" ]]
    }

    # Symlink management (only when target changes)
    manage_symlink() {
      local target_dir="$HOME/.local/bin"
      local symlink_path="$target_dir/btca"
      local binary_path="@out@/bin/.btca-unwrapped"

      # If Home Manager is active, clean up our symlink if it exists and skip creation
      if is_home_manager_active; then
        if [[ -L "$symlink_path" ]]; then
          local link_target
          link_target="$(readlink "$symlink_path" 2>/dev/null || echo "")"
          # Match exact current path OR any older version of this package
          if [[ "$link_target" == "$binary_path" ]] || \
             [[ "$link_target" == /nix/store/*-btca-* ]]; then
            rm -f "$symlink_path"
            [[ "$verbose" == "1" ]] && echo "[btca-nix] Removed symlink (Home Manager now manages btca)" >&2
          fi
        fi
        return 0
      fi

      # Check if symlink already points to the correct target
      local current_target
      current_target="$(readlink -f "$symlink_path" 2>/dev/null || echo "")"

      if [[ "$current_target" == "$binary_path" ]]; then
        return 0  # Already correct
      fi

      # Create or update symlink
      mkdir -p "$target_dir"
      ln -sf "$binary_path" "$symlink_path"
      [[ "$verbose" == "1" ]] && echo "[btca-nix] Created symlink: $symlink_path -> $binary_path" >&2
    }

    config_dir="$HOME/.config/btca"
    config_path="$config_dir/btca.config.jsonc"
    mkdir -p "$config_dir"
    hash_path="$config_dir/.nix-settings-hash"
    tmp_config="$config_path.tmp"

    jq_bin="${jq}/bin/jq"
    nix_settings_path="@nix_settings_path@"

    hash_file() {
      if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
      else
        shasum -a 256 "$1" | awk '{print $1}'
      fi
    }

    if [[ -f "$nix_settings_path" ]]; then
      nix_settings_hash="$(hash_file "$nix_settings_path")"
    else
      nix_settings_hash=""
    fi

    if [[ -n "$nix_settings_hash" ]]; then
      if [[ ! -f "$config_path" ]]; then
        mkdir -p "$config_dir"
        cp "$nix_settings_path" "$config_path"
        printf "%s" "$nix_settings_hash" > "$hash_path"
        [[ "$verbose" == "1" ]] && echo "[btca-nix] Seeded config at $config_path" >&2
      else
        existing_hash="$(cat "$hash_path" 2>/dev/null || true)"
        if [[ "$existing_hash" != "$nix_settings_hash" ]]; then
          mkdir -p "$config_dir"
          "$jq_bin" -s '.[0] * .[1]' "$nix_settings_path" "$config_path" > "$tmp_config"
          mv "$tmp_config" "$config_path"
          printf "%s" "$nix_settings_hash" > "$hash_path"
          [[ "$verbose" == "1" ]] && echo "[btca-nix] Merged Nix config into $config_path" >&2
        fi
      fi
    fi

    # Run symlink management
    manage_symlink

    # Execute the actual binary
    exec "@out@/bin/.btca-unwrapped" "$@"

  '';
in
stdenv.mkDerivation {
  pname = "btca";
  inherit version src;

  sourceRoot = ".";

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    autoPatchelfHook
  ];

  # autoPatchelfHook will find required libraries automatically
  # Add any additional build inputs here if needed
  buildInputs = [ ];

  dontStrip = true;

  unpackPhase = ''
    runHook preUnpack
    tar -xzf $src
    runHook postUnpack
  '';

  installPhase = ''
        runHook preInstall
        mkdir -p $out/bin

        # Install unwrapped binary
        cp package/dist/btca-${platform} $out/bin/.btca-unwrapped
        chmod +x $out/bin/.btca-unwrapped

        # Install wrapper script
        cat > $out/bin/btca << 'WRAPPER_EOF'
    ${wrapperScript}
    WRAPPER_EOF
        chmod +x $out/bin/btca

        # Substitute @out@ placeholder
        substituteInPlace $out/bin/btca --replace-quiet "@out@" "$out"

        # Substitute Nix settings path placeholder
        substituteInPlace $out/bin/btca --replace-quiet "@nix_settings_path@" "${settingsJson}"

        runHook postInstall
  '';

  meta = with lib; {
    description = "Better Context - search library source code for AI agents";
    homepage = "https://btca.dev";
    license = licenses.mit;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    mainProgram = "btca";
  };
}
