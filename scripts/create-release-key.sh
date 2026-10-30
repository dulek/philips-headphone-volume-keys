#!/usr/bin/env bash
# Copyright 2026 Michał Dulko
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

signing_dir="${SIGNING_DIR:-$HOME/.local/share/philips-headphone-volume-keys/signing}"
if [[ -e "$signing_dir/release.jks" || -e "$signing_dir/store.pass" || -e "$signing_dir/key.pass" ]]; then
    echo "Release signing files already exist in $signing_dir; refusing to replace them." >&2
    exit 1
fi

umask 077
mkdir -p "$signing_dir"
openssl rand -hex 32 > "$signing_dir/store.pass"
openssl rand -hex 32 > "$signing_dir/key.pass"
export RELEASE_STORE_PASSWORD="$(< "$signing_dir/store.pass")"
export RELEASE_KEY_PASSWORD="$(< "$signing_dir/key.pass")"
keytool -genkeypair -noprompt \
    -keystore "$signing_dir/release.jks" -storetype JKS \
    -storepass:env RELEASE_STORE_PASSWORD -keypass:env RELEASE_KEY_PASSWORD \
    -alias philips-headphone -keyalg RSA -keysize 4096 -validity 12000 \
    -dname 'CN=Philips Headphone Volume Keys, O=Michal Dulko'
unset RELEASE_STORE_PASSWORD RELEASE_KEY_PASSWORD
chmod 600 "$signing_dir/release.jks" "$signing_dir/store.pass" "$signing_dir/key.pass"
echo "Release key created in $signing_dir. Back up all three files securely."
