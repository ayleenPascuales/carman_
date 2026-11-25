#!/usr/bin/env bash
set -euo pipefail

# Report the failing step; Vercel's final BUILD_UTILS_SPAWN message hides it.
stage="inicialización"
trap 'code=$?; printf "Falló la etapa %s (código %s). Revisa el error anterior en el log.\n" "$stage" "$code" >&2' ERR

# Vercel does not ship the Flutter SDK. Use a pinned, checksum-verified release.
# FLUTTER_BIN can point to an existing Linux installation for local builds.
if [[ -n "${FLUTTER_BIN:-}" ]]; then
  flutter="$FLUTTER_BIN"
else
  stage="descarga del SDK de Flutter"
  temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/carman-flutter.XXXXXX")"
  trap 'rm -rf "$temp_dir"' EXIT
  archive="$temp_dir/flutter.tar.xz"
  curl --fail --location --retry 3 --silent --show-error \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.50.1-stable.tar.xz" \
    --output "$archive"
  stage="verificación del SDK de Flutter"
  echo "4ad17fc8462fbcef2ba19ff4a78c0a16b7147fde1add8578e267ea62cdb92678  $archive" | sha256sum --check --status
  stage="extracción del SDK de Flutter"
  tar --no-same-owner -xJf "$archive" -C "$temp_dir"
  rm "$archive"
  flutter="$temp_dir/flutter/bin/flutter"

  # Flutter calls Git inside its SDK. Some CI runners extract its Git metadata
  # under a different UID, causing Git to exit 128 ("dubious ownership").
  # Trust only the verified, temporary SDK path for this build process.
  git_config_index="${GIT_CONFIG_COUNT:-0}"
  export GIT_CONFIG_COUNT="$((git_config_index + 1))"
  export "GIT_CONFIG_KEY_${git_config_index}=safe.directory"
  export "GIT_CONFIG_VALUE_${git_config_index}=$temp_dir/flutter"
  stage="Git del SDK de Flutter"
  git -C "$temp_dir/flutter" rev-parse --verify HEAD >/dev/null
fi

stage="resolución de dependencias Flutter"
"$flutter" pub get --enforce-lockfile
stage="compilación de Flutter Web"
"$flutter" build web --release --dart-define=CARMAN_USE_LIVE_API=true
stage="verificación de archivos generados"
test -s build/web/index.html
test -s build/web/main.dart.js
