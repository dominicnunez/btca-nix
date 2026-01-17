{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,
  writeText,
  # ============================================================
  # OPTIONAL: Extension/settings arguments
  # ============================================================
  # Uncomment if your application supports plugins/extensions or settings.
  # Delete these lines if not applicable.
  #
  # extensions ? [ ],
  # userSettings ? null,
  # userKeybindings ? null,
  # ============================================================

  # ============================================================
  # REPLACE: Linux runtime dependencies
  # ============================================================
  # Add/remove dependencies based on your application's requirements.
  # Common dependencies for GUI/Electron apps are listed below.
  gtk3,
  glib,
  nss,
  nspr,
  atk,
  at-spi2-atk,
  at-spi2-core,
  cups,
  dbus,
  expat,
  libdrm,
  libxkbcommon,
  mesa,
  pango,
  cairo,
  alsa-lib,
  xorg,
  libsecret,
  libnotify,
  systemd,
  # Additional runtime dependencies
  xdg-utils,
  krb5,
  libglvnd,
  wayland,
  libpulseaudio,
  libva,
  coreutils,
  git,
  jq,
  # macOS dependencies
  unzip,
}:

let
  versionInfo = lib.importJSON ./version.json;
  version = versionInfo.version;
  hashes = versionInfo.hashes;

  # Platform-specific configuration
  # REPLACE: Adjust platform names to match your binary source
  platformConfig = {
    x86_64-linux = {
      platform = "linux-x64";
      archive = "tar.gz";
    };
    aarch64-linux = {
      platform = "linux-arm64";
      archive = "tar.gz";
    };
    x86_64-darwin = {
      platform = "darwin-x64";
      archive = "zip";
    };
    aarch64-darwin = {
      platform = "darwin-arm64";
      archive = "zip";
    };
  };

  system = stdenv.hostPlatform.system;
  config = platformConfig.${system} or (throw "Unsupported system: ${system}");
  hash = hashes.${system} or (throw "No hash for system: ${system}");

  # REPLACE: Update URL to match your binary source
  src = fetchurl {
    url = "https://example.com/releases/v${version}/myapp-${config.platform}.${config.archive}";
    inherit hash;
  };

  # ============================================================
  # OPTIONAL: Extension/settings file generation
  # ============================================================
  # Uncomment if using extensions/settings management.
  #
  # extensionsList =
  #   if extensions != [ ] then
  #     writeText "myapp-extensions.txt" (lib.concatStringsSep "\n" extensions)
  #   else
  #     null;
  #
  # settingsJson =
  #   if userSettings != null then
  #     writeText "myapp-settings.json" (builtins.toJSON userSettings)
  #   else
  #     null;
  #
  # keybindingsJson =
  #   if userKeybindings != null then
  #     writeText "myapp-keybindings.json" (builtins.toJSON userKeybindings)
  #   else
  #     null;
  # ============================================================

  # Shared wrapper script template for both Linux and macOS
  # Placeholders are replaced with actual paths during installation
  sharedWrapperScript = ''
    #!/usr/bin/env bash
    set -euo pipefail

    # Verbose output (opt-in via MYAPP_NIX_VERBOSE=1)
    verbose=''${MYAPP_NIX_VERBOSE:-0}

    # Home Manager detection function
    is_home_manager_active() {
      [[ -n "''${HM_SESSION_VARS:-}" ]] ||
      [[ -d "$HOME/.config/home-manager" ]] ||
      [[ -d "/etc/profiles/per-user/$USER" ]]
    }

    # Manage ~/.local/bin/myapp symlink based on Home Manager detection
    manage_symlink() {
      local target_dir="$HOME/.local/bin"
      local symlink_path="$target_dir/myapp"
      local binary_path="MYAPP_BIN_PLACEHOLDER"

                # If Home Manager is active, clean up our symlink if it exists and skip creation
                  if is_home_manager_active; then
                    if [[ -L "$symlink_path" ]]; then
                      local link_target
                      link_target="$(readlink "$symlink_path" 2>/dev/null || echo "")"
                      # Match exact current path OR any older version of this package
                      # REPLACE: Change -myapp- to match your pname (e.g., -vscode-, -opencode-)
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
      [[ "$verbose" == "1" ]] && echo "[myapp-nix] Created ~/.local/bin/myapp symlink" >&2
    }

    # Set up environment
    export XDG_DATA_HOME="''${XDG_DATA_HOME:-$HOME/.local/share}"
    export XDG_CONFIG_HOME="''${XDG_CONFIG_HOME:-$HOME/.config}"
    export PATH="EXTRA_PATH_PLACEHOLDER:$PATH"

    # Run symlink management
    manage_symlink

    # Set LD_LIBRARY_PATH for Linux (empty/harmless on macOS)
    if [[ -n "EXTRA_LD_LIBRARY_PATH_PLACEHOLDER" ]]; then
      export LD_LIBRARY_PATH="EXTRA_LD_LIBRARY_PATH_PLACEHOLDER:''${LD_LIBRARY_PATH:-}"
    fi

    # ============================================================
    # OPTIONAL: Extension/settings management
    # ============================================================
    # This section provides scaffolding for applications that support
    # plugins/extensions or user-configurable settings.
    #
    # NOT APPLICABLE TO ALL APPLICATIONS - only enable if your app:
    # 1. Has a plugin/extension system
    # 2. Has user settings stored in JSON/config files
    # 3. Benefits from declarative configuration via Nix
    #
    # If not applicable, delete this entire commented section.
    #
    # EXTENSIONS_DIR="''${XDG_DATA_HOME}/myapp-nix/extensions"
    # EXTENSIONS_LIST="EXTENSIONS_LIST_PLACEHOLDER"
    # EXTENSIONS_MARKER="''${XDG_DATA_HOME}/myapp-nix/.extensions-installed"
    #
    # NIX_SETTINGS_JSON="NIX_SETTINGS_JSON_PLACEHOLDER"
    # NIX_KEYBINDINGS_JSON="NIX_KEYBINDINGS_JSON_PLACEHOLDER"
    # USER_DATA_DIR="''${XDG_DATA_HOME}/myapp-nix/user-data"
    # SETTINGS_MARKER="''${USER_DATA_DIR}/.settings-initialized"
    # KEYBINDINGS_MARKER="''${USER_DATA_DIR}/.keybindings-initialized"
    #
    # # Cross-platform md5 hash function
    # compute_md5() {
    #   local file="$1"
    #   if command -v md5sum &>/dev/null; then
    #     md5sum "$file" 2>/dev/null | cut -d' ' -f1
    #   elif command -v md5 &>/dev/null; then
    #     md5 -q "$file" 2>/dev/null
    #   else
    #     echo ""
    #   fi
    # }
    #
    # # Initialize settings from Nix-provided defaults
    # initialize_settings() {
    #   if [[ "$NIX_SETTINGS_JSON" != "" ]] && [[ -f "$NIX_SETTINGS_JSON" ]]; then
    #     local settings_dir="''${USER_DATA_DIR}/User"
    #     local settings_hash
    #     settings_hash=$(compute_md5 "$NIX_SETTINGS_JSON")
    #
    #     if [[ ! -f "$SETTINGS_MARKER" ]] || [[ "$(cat "$SETTINGS_MARKER" 2>/dev/null)" != "$settings_hash" ]]; then
    #       mkdir -p "$settings_dir"
    #       mkdir -p "$(dirname "$SETTINGS_MARKER")"
    #
    #       if [[ -f "''${settings_dir}/settings.json" ]]; then
    #         if command -v jq &>/dev/null; then
    #           local tmp_settings
    #           tmp_settings=$(mktemp)
    #           jq -s '.[0] * .[1]' "$NIX_SETTINGS_JSON" "''${settings_dir}/settings.json" > "$tmp_settings" 2>/dev/null && \
    #             mv "$tmp_settings" "''${settings_dir}/settings.json" || rm -f "$tmp_settings"
    #           [[ "$verbose" == "1" ]] && echo "[myapp-nix] Merged Nix defaults with existing user settings" >&2
    #         fi
    #       else
    #         cp "$NIX_SETTINGS_JSON" "''${settings_dir}/settings.json"
    #         [[ "$verbose" == "1" ]] && echo "[myapp-nix] Copied Nix settings as defaults" >&2
    #       fi
    #       echo "$settings_hash" > "$SETTINGS_MARKER"
    #     fi
    #   fi
    # }
    #
    # # Install extensions on first run or when list changes
    # install_extensions() {
    #   if [[ "$EXTENSIONS_LIST" != "" ]] && [[ -f "$EXTENSIONS_LIST" ]]; then
    #     local list_hash
    #     list_hash=$(compute_md5 "$EXTENSIONS_LIST")
    #
    #     if [[ ! -f "$EXTENSIONS_MARKER" ]] || [[ "$(cat "$EXTENSIONS_MARKER" 2>/dev/null)" != "$list_hash" ]]; then
    #       mkdir -p "$EXTENSIONS_DIR"
    #       mkdir -p "$(dirname "$EXTENSIONS_MARKER")"
    #
    #       [[ "$verbose" == "1" ]] && echo "[myapp-nix] Installing extensions..." >&2
    #
    #       while IFS= read -r extension || [[ -n "$extension" ]]; do
    #         [[ -z "$extension" ]] && continue
    #         [[ "$verbose" == "1" ]] && echo "[myapp-nix] Installing: $extension" >&2
    #         "MYAPP_BIN_PLACEHOLDER" --extensions-dir "$EXTENSIONS_DIR" --install-extension "$extension" --force 2>/dev/null || true
    #       done < "$EXTENSIONS_LIST"
    #
    #       echo "$list_hash" > "$EXTENSIONS_MARKER"
    #       [[ "$verbose" == "1" ]] && echo "[myapp-nix] Extensions installation complete" >&2
    #     fi
    #   fi
    # }
    #
    # initialize_settings
    # install_extensions
    #
    # # Build command arguments
    # MYAPP_ARGS=()
    # if [[ "$EXTENSIONS_LIST" != "" ]] && [[ -f "$EXTENSIONS_LIST" ]]; then
    #   MYAPP_ARGS+=(--extensions-dir "$EXTENSIONS_DIR")
    # fi
    # if [[ "$NIX_SETTINGS_JSON" != "" ]] && [[ -f "$NIX_SETTINGS_JSON" ]]; then
    #   MYAPP_ARGS+=(--user-data-dir "$USER_DATA_DIR")
    # fi
    #
    # exec "MYAPP_BIN_PLACEHOLDER" "''${MYAPP_ARGS[@]}" "$@"
    # ============================================================

    # Simple execution (use this if not using extension/settings management)
    exec "MYAPP_BIN_PLACEHOLDER" "$@"
  '';

  # Linux-specific derivation
  linuxPackage = stdenv.mkDerivation {
    pname = "myapp";
    inherit version src;

    nativeBuildInputs = [
      autoPatchelfHook
      makeWrapper
      wrapGAppsHook3
    ];

    # REPLACE: Adjust buildInputs based on your application's dependencies
    buildInputs = [
      # GTK and UI
      gtk3
      glib
      pango
      cairo
      atk
      at-spi2-atk
      at-spi2-core

      # Electron/Chromium dependencies
      nss
      nspr
      cups
      dbus
      expat
      libdrm
      libxkbcommon
      mesa
      libglvnd
      alsa-lib

      # X11 libraries
      xorg.libX11
      xorg.libXcomposite
      xorg.libXcursor
      xorg.libXdamage
      xorg.libXext
      xorg.libXfixes
      xorg.libXi
      xorg.libXrandr
      xorg.libXrender
      xorg.libXScrnSaver
      xorg.libXtst
      xorg.libxcb
      xorg.libxkbfile

      # Security and credentials
      libsecret
      krb5

      # Notifications
      libnotify

      # System services
      systemd

      # Wayland support
      wayland

      # Audio
      libpulseaudio

      # Video/hardware acceleration
      libva
    ];

    runtimeDependencies = [
      systemd
    ];

    dontConfigure = true;
    dontBuild = true;

    unpackPhase = ''
      runHook preUnpack
      tar xzf $src
      runHook postUnpack
    '';

    installPhase = ''
            runHook preInstall

            mkdir -p $out/lib/myapp $out/bin
            # REPLACE: Adjust the source directory name based on your archive structure
            cp -r myapp-*/* $out/lib/myapp/

            # Write shared wrapper script template
            cat > $out/bin/myapp << 'WRAPPER_EOF'
      ${sharedWrapperScript}
      WRAPPER_EOF

            # Replace placeholders with actual paths
            substituteInPlace $out/bin/myapp \
              --replace-fail "MYAPP_BIN_PLACEHOLDER" "$out/lib/myapp/bin/myapp" \
              --replace-fail "EXTRA_PATH_PLACEHOLDER" "${
                lib.makeBinPath [
                  xdg-utils
                  git
                  coreutils
                  jq
                ]
              }" \
              --replace-fail "EXTRA_LD_LIBRARY_PATH_PLACEHOLDER" "${
                lib.makeLibraryPath [
                  libpulseaudio
                  libva
                  wayland
                  libglvnd
                ]
              }"

            chmod +x $out/bin/myapp

            runHook postInstall
    '';
    # ============================================================
    # OPTIONAL: Extension/settings placeholder substitution
    # ============================================================
    # If using extension/settings management, add these to substituteInPlace:
    #
    #   --replace-fail "EXTENSIONS_LIST_PLACEHOLDER" "''${
    #     if extensionsList != null then extensionsList else ""
    #   }" \
    #   --replace-fail "NIX_SETTINGS_JSON_PLACEHOLDER" "''${
    #     if settingsJson != null then settingsJson else ""
    #   }" \
    #   --replace-fail "NIX_KEYBINDINGS_JSON_PLACEHOLDER" "''${
    #     if keybindingsJson != null then keybindingsJson else ""
    #   }"
    # ============================================================

    # REPLACE: Update meta attributes for your application
    meta = with lib; {
      description = "REPLACE WITH YOUR APP DESCRIPTION";
      homepage = "https://example.com";
      license = licenses.unfree; # REPLACE: Use appropriate license
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      mainProgram = "myapp";
    };
  };

  # macOS-specific derivation
  darwinPackage = stdenv.mkDerivation {
    pname = "myapp";
    inherit version src;

    nativeBuildInputs = [
      unzip
      makeWrapper
      jq
    ];

    dontConfigure = true;
    dontBuild = true;

    unpackPhase = ''
      runHook preUnpack
      unzip -q $src
      runHook postUnpack
    '';

    installPhase = ''
            runHook preInstall

            mkdir -p $out/Applications $out/bin

            # REPLACE: Adjust the app bundle name
            cp -r "MyApp.app" $out/Applications/

            # Write shared wrapper script template
            cat > $out/bin/myapp << 'WRAPPER_EOF'
      ${sharedWrapperScript}
      WRAPPER_EOF

            # Replace placeholders with actual paths (macOS-specific values)
            # REPLACE: Adjust the binary path inside the app bundle
            substituteInPlace $out/bin/myapp \
              --replace-fail "MYAPP_BIN_PLACEHOLDER" "$out/Applications/MyApp.app/Contents/MacOS/myapp" \
              --replace-fail "EXTRA_PATH_PLACEHOLDER" "${lib.makeBinPath [ jq ]}" \
              --replace-fail "EXTRA_LD_LIBRARY_PATH_PLACEHOLDER" ""

            chmod +x $out/bin/myapp

            runHook postInstall
    '';
    # ============================================================
    # OPTIONAL: Extension/settings placeholder substitution
    # ============================================================
    # If using extension/settings management, add these to substituteInPlace:
    #
    #   --replace-fail "EXTENSIONS_LIST_PLACEHOLDER" "''${
    #     if extensionsList != null then extensionsList else ""
    #   }" \
    #   --replace-fail "NIX_SETTINGS_JSON_PLACEHOLDER" "''${
    #     if settingsJson != null then settingsJson else ""
    #   }" \
    #   --replace-fail "NIX_KEYBINDINGS_JSON_PLACEHOLDER" "''${
    #     if keybindingsJson != null then keybindingsJson else ""
    #   }"
    # ============================================================

    # REPLACE: Update meta attributes for your application
    meta = with lib; {
      description = "REPLACE WITH YOUR APP DESCRIPTION";
      homepage = "https://example.com";
      license = licenses.unfree; # REPLACE: Use appropriate license
      platforms = [
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      mainProgram = "myapp";
    };
  };

in
if stdenv.isDarwin then darwinPackage else linuxPackage
