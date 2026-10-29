# Copyright 2026 Michał Dulko
# SPDX-License-Identifier: Apache-2.0

ADB ?= adb
TV_PORT ?= 5555
ADB_SERIAL ?=
TV_HOST ?=
APK := app/build/outputs/apk/debug/app-debug.apk

.PHONY: help build connect check-device install install-built enable disable status

help:
	@printf '%s\n' \
	  'make build                         Build the debug APK (JDK 17 and Android SDK 34 required)' \
	  'make connect TV_HOST=<tv-ip>       Connect to network ADB on port 5555' \
	  'make install ADB_SERIAL=<serial>   Build and install the APK' \
	  'make install-built ADB_SERIAL=<serial>  Install an APK already built' \
	  'make enable ADB_SERIAL=<serial>    Enable this accessibility service only' \
	  'make disable ADB_SERIAL=<serial>   Disable this accessibility service only' \
	  'make status ADB_SERIAL=<serial>    Check the service on the TV'

build:
	./gradlew --no-daemon assembleDebug

connect:
	@test -n "$(TV_HOST)" || { echo 'Set TV_HOST to the TV IP address.' >&2; exit 1; }
	$(ADB) connect "$(TV_HOST):$(TV_PORT)"

check-device:
	@test -n "$(ADB_SERIAL)" || { echo 'Set ADB_SERIAL to the ADB device serial or IP:port.' >&2; exit 1; }
	@$(ADB) -s "$(ADB_SERIAL)" get-state | grep -qx device

install: check-device build install-built

install-built: check-device
	@test -f "$(APK)" || { echo 'Build the APK first with make build.' >&2; exit 1; }
	$(ADB) -s "$(ADB_SERIAL)" install -r "$(APK)"

enable: check-device
	ADB="$(ADB)" scripts/accessibility.sh enable "$(ADB_SERIAL)"

disable: check-device
	ADB="$(ADB)" scripts/accessibility.sh disable "$(ADB_SERIAL)"

status: check-device
	ADB="$(ADB)" scripts/accessibility.sh status "$(ADB_SERIAL)"
