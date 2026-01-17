{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:

let
  versionInfo = lib.importJSON ./version.json;
  version = versionInfo.version;
  # Map Nix system to binary asset platform suffix
  # REPLACE: Adjust values to match your binary source's naming convention
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

  # npm registry tarball URL (single tarball contains all platform binaries)
  src = fetchurl {
    url = "https://registry.npmjs.org/btca/-/btca-${version}.tgz";
    inherit hash;
  };

  # Home Manager detection wrapper script (macOS only)
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

    ${
      if isDarwin then
        ''
                # macOS: Install unwrapped binary and wrapper script
                cp package/dist/btca-${platform} $out/bin/.btca-unwrapped
                chmod +x $out/bin/.btca-unwrapped

                # Install wrapper script with Home Manager detection
                cat > $out/bin/btca << 'WRAPPER_EOF'
          ${wrapperScript}
          WRAPPER_EOF
                chmod +x $out/bin/btca

                # Substitute @out@ placeholder
                substituteInPlace $out/bin/btca --replace-quiet "@out@" "$out"
        ''
      else
        ''
          # Linux: Install binary directly (no wrapper needed)
          cp package/dist/btca-${platform} $out/bin/btca
          chmod +x $out/bin/btca
        ''
    }

    runHook postInstall
  '';

  # REPLACE: Update meta attributes for your application
  meta = with lib; {
    description = "Better Context - search library source code for AI agents";
    homepage = "https://btca.dev";
    license = licenses.mit; # REPLACE: Use appropriate license
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    mainProgram = "btca";
  };
}
