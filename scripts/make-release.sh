#!/usr/bin/env bash
# Copyright 2026 Michał Dulko
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
signing_dir="${SIGNING_DIR:-$HOME/.local/share/philips-headphone-volume-keys/signing}"
image="${IMAGE:-philips-headphone-android-build}"
gradle_volume="${GRADLE_VOLUME:-philips-headphone-gradle}"
docker_bin="${DOCKER:-docker}"

for name in release.jks store.pass key.pass; do
    [[ -f "$signing_dir/$name" ]] || {
        echo "Missing $signing_dir/$name; run make release-key first." >&2
        exit 1
    }
done
signing_dir="$(cd "$signing_dir" && pwd -P)"
version="$(sed -n "s/.*versionName '\([^']*\)'.*/\1/p" "$repo/app/build.gradle" | head -1)"
[[ -n "$version" ]] || { echo 'Could not read versionName from app/build.gradle.' >&2; exit 1; }
mkdir -p "$repo/dist"

if ! "$docker_bin" image inspect "$image" >/dev/null 2>&1; then
    "$docker_bin" build -t "$image" "$repo/docker"
fi

"$docker_bin" run --rm --user "$(id -u):$(id -g)" \
    -v "$repo:/workspace" -v "$gradle_volume:/gradle" \
    -v "$signing_dir:/signing:ro" -w /workspace \
    -e ANDROID_USER_HOME=/gradle/.android -e RELEASE_VERSION="$version" \
    "$image" sh -eu -c '
        ./gradlew --no-daemon --console=plain assembleRelease
        build_tools=/opt/android-sdk/build-tools/34.0.0
        unsigned=app/build/outputs/apk/release/app-release-unsigned.apk
        aligned=app/build/outputs/apk/release/app-release-aligned.apk
        output="dist/philips-headphone-volume-keys-${RELEASE_VERSION}.apk"
        test -f "$unsigned"
        "$build_tools/zipalign" -f -p 4 "$unsigned" "$aligned"
        "$build_tools/apksigner" sign --ks /signing/release.jks \
            --ks-type JKS --ks-key-alias philips-headphone \
            --ks-pass file:/signing/store.pass --key-pass file:/signing/key.pass \
            --out "$output" "$aligned"
        "$build_tools/apksigner" verify --verbose --print-certs "$output"
        "$build_tools/aapt" dump badging "$output" | head -5
    '

(cd "$repo/dist" && sha256sum "philips-headphone-volume-keys-${version}.apk" \
    > "philips-headphone-volume-keys-${version}.apk.sha256")
echo "Release APK: $repo/dist/philips-headphone-volume-keys-${version}.apk"
