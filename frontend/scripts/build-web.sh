#!/usr/bin/env bash
set -euo pipefail

# Vercel does not ship the Flutter SDK. Use a pinned, checksum-verified release.
# FLUTTER_BIN can point to an existing Linux installation for local builds.
if [[ -n "${FLUTTER_BIN:-}" ]]; then
  flutter="$FLUTTER_BIN"
else
  temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/carman-flutter.XXXXXX")"
  trap 'rm -rf "$temp_dir"' EXIT
  archive="$temp_dir/flutter.tar.xz"
  curl --fail --location --retry 3 --silent --show-error \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.50.1-stable.tar.xz" \
    --output "$archive"
  echo "4ad17fc8462fbcef2ba19ff4a78c0a16b7147fde1add8578e267ea62cdb92678  $archive" | sha256sum --check --status
  tar -xJf "$archive" -C "$temp_dir"
  rm "$archive"
  flutter="$temp_dir/flutter/bin/flutter"
fi

"$flutter" pub get --enforce-lockfile
"$flutter" build web --release --dart-define=CARMAN_USE_LIVE_API=true
test -s build/web/index.html
test -s build/web/main.dart.js
