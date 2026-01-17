{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  # REPLACE: Add runtime dependencies as needed
  # Example: procps, bubblewrap, socat for sandboxing
}:

let
  versionInfo = lib.importJSON ./version.json;
  version = versionInfo.version;
  hashes = versionInfo.hashes;

  # Map Nix system to binary platform suffix
  # REPLACE: Adjust values to match your binary source's naming convention
  platformMap = {
    "x86_64-linux" = "linux-x64";
    "aarch64-linux" = "linux-arm64";
    "x86_64-darwin" = "darwin-x64";
    "aarch64-darwin" = "darwin-arm64";
  };

  # REPLACE: Set your manifest/binary base URL
  baseUrl = "https://storage.example.com/myapp-releases";

  isDarwin = stdenv.hostPlatform.isDarwin;
  isLinux = stdenv.hostPlatform.isLinux;

  system = stdenv.hostPlatform.system;
  platform = platformMap.${system} or (throw "Unsupported system: ${system}");
  hash = hashes.${system} or (throw "No hash for system: ${system}");

  # REPLACE: Adjust URL pattern to match your binary source
  # Common patterns:
  #   ${baseUrl}/${version}/${platform}/binary
  #   ${baseUrl}/v${version}/myapp-${platform}.tar.gz
  src = fetchurl {
    url = "${baseUrl}/${version}/${platform}/myapp";
    inherit hash;
  };

  # Home Manager detection wrapper script
  wrapperScript = ''
    #!/usr/bin/env bash

    # Verbose output (opt-in via MYAPP_NIX_VERBOSE=1)
    verbose=''${MYAPP_NIX_VERBOSE:-0}

    # Home Manager detection function
    is_home_manager_active() {
      [[ -n "''${HM_SESSION_VARS:-}" ]] ||
      [[ -d "$HOME/.config/home-manager" ]] ||
      [[ -d "/etc/profiles/per-user/$USER" ]]
    }

    # Symlink management (only when target changes)
    manage_symlink() {
      local target_dir="$HOME/.local/bin"
      local symlink_path="$target_dir/myapp"
      local binary_path="@out@/bin/.myapp-unwrapped"

      # If Home Manager is active, clean up our symlink if it exists and skip creation
      if is_home_manager_active; then
        if [[ -L "$symlink_path" ]]; then
          local link_target
          link_target="$(readlink "$symlink_path" 2>/dev/null || echo "")"
          # Match exact current path OR any older version of this package
          # REPLACE: Change -myapp- to match your pname
          if [[ "$link_target" == "$binary_path" ]] || \
             [[ "$link_target" == /nix/store/*-myapp-* ]]; then
            rm -f "$symlink_path"
            [[ "$verbose" == "1" ]] && echo "[myapp-nix] Removed symlink (Home Manager now manages myapp)" >&2
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
      [[ "$verbose" == "1" ]] && echo "[myapp-nix] Created symlink: $symlink_path -> $binary_path" >&2
    }

    # Run symlink management
    manage_symlink

    # Execute the actual binary
    exec "@out@/bin/.myapp-unwrapped" "$@"
  '';
in
stdenv.mkDerivation {
  pname = "myapp";
  inherit version;

  # Source is a single binary file, not an archive
  # REPLACE: If your source is an archive (tar.gz, zip), remove dontUnpack
  # and add appropriate unpackPhase
  dontUnpack = true;

  nativeBuildInputs = [
    makeWrapper
  ];

  installPhase = ''
        runHook preInstall

        mkdir -p $out/bin

        # Install the binary
        # REPLACE: Adjust based on your source structure
        # For single binary: install -m755 ${src} $out/bin/.myapp-unwrapped
        # For archive: cp extracted/path/to/binary $out/bin/.myapp-unwrapped
        install -m755 ${src} $out/bin/.myapp-unwrapped

        # Install wrapper script with Home Manager detection
        cat > $out/bin/myapp << 'WRAPPER_EOF'
    ${wrapperScript}
    WRAPPER_EOF
        chmod +x $out/bin/myapp

        # Substitute @out@ placeholder
        substituteInPlace $out/bin/myapp --replace-quiet "@out@" "$out"

    # REPLACE: Add wrapProgram if you need environment variables or PATH additions
    # Example with runtime dependencies:
    #   wrapProgram $out/bin/myapp \
    #     --set SOME_ENV_VAR "value" \
    #     --prefix PATH : ''${lib.makeBinPath [ some-package ]}

    runHook postInstall
  '';

  # REPLACE: Update meta attributes for your application
  meta = with lib; {
    description = "REPLACE WITH YOUR APP DESCRIPTION";
    homepage = "https://example.com";
    # REPLACE: Use the upstream application's license
    # licenses.mit, licenses.asl20, licenses.unfree, etc.
    license = licenses.unfree;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    mainProgram = "myapp";
  };
}
