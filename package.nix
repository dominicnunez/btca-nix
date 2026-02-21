{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:

let
  versionInfo = lib.importJSON ./version.json;
  version = versionInfo.version;
  platformMap = {
    "x86_64-linux" = "linux-x64";
    "aarch64-linux" = "linux-arm64";
    "x86_64-darwin" = "darwin-x64";
    "aarch64-darwin" = "darwin-arm64";
  };

  system = stdenv.hostPlatform.system;
  platform = platformMap.${system} or (throw "Unsupported system: ${system}");
  hash = versionInfo.hash;

  src = fetchurl {
    url = "https://registry.npmjs.org/btca/-/btca-${version}.tgz";
    inherit hash;
  };

  wrapperScript = ''
    #!/usr/bin/env bash

    verbose=''${BTCA_NIX_VERBOSE:-0}

    is_home_manager_active() {
      [[ -n "''${HM_SESSION_VARS:-}" ]] ||
      [[ -d "$HOME/.config/home-manager" ]] ||
      [[ -d "/etc/profiles/per-user/$USER" ]]
    }

    manage_symlink() {
      local target_dir="$HOME/.local/bin"
      local symlink_path="$target_dir/btca"
      local binary_path="@out@/bin/.btca-unwrapped"

      if is_home_manager_active; then
        if [[ -L "$symlink_path" ]]; then
          local link_target
          link_target="$(readlink "$symlink_path" 2>/dev/null || echo "")"
          if [[ "$link_target" == "$binary_path" ]] || \
             [[ "$link_target" == /nix/store/*-btca-* ]]; then
            rm -f "$symlink_path"
            [[ "$verbose" == "1" ]] && echo "[btca-nix] Removed symlink (Home Manager now manages btca)" >&2
          fi
        fi
        return 0
      fi

      local current_target
      current_target="$(readlink -f "$symlink_path" 2>/dev/null || echo "")"

      if [[ "$current_target" == "$binary_path" ]]; then
        return 0
      fi

      mkdir -p "$target_dir"
      ln -sf "$binary_path" "$symlink_path"
      [[ "$verbose" == "1" ]] && echo "[btca-nix] Created symlink: $symlink_path -> $binary_path" >&2
    }

    manage_symlink

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

        cp package/dist/btca-${platform} $out/bin/.btca-unwrapped
        chmod +x $out/bin/.btca-unwrapped

        cat > $out/bin/btca << 'WRAPPER_EOF'
    ${wrapperScript}
    WRAPPER_EOF
        chmod +x $out/bin/btca

        substituteInPlace $out/bin/btca --replace-quiet "@out@" "$out"

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
