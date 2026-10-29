#!/usr/bin/env bash
# Copyright 2026 Michał Dulko
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

action="${1:-}"
serial="${2:-}"
adb_bin="${ADB:-adb}"
service='local.philips.headphone/.HeadphoneKeyService'

if [[ -z "$serial" ]]; then
    echo 'Usage: accessibility.sh enable|disable|status <adb-serial>' >&2
    exit 2
fi

current="$("$adb_bin" -s "$serial" shell settings get secure enabled_accessibility_services | tr -d '\r')"
[[ "$current" == null ]] && current=''
IFS=: read -r -a entries <<< "$current"
kept=()
found=false
for entry in "${entries[@]}"; do
    [[ -z "$entry" ]] && continue
    if [[ "$entry" == "$service" ]]; then
        found=true
    else
        kept+=("$entry")
    fi
done

case "$action" in
    enable)
        if [[ "$found" == true ]]; then
            echo 'Headphone service is already enabled.'
            exit 0
        fi
        kept+=("$service")
        joined="$(IFS=:; echo "${kept[*]}")"
        "$adb_bin" -s "$serial" shell settings put secure enabled_accessibility_services "$joined"
        "$adb_bin" -s "$serial" shell settings put secure accessibility_enabled 1
        echo 'Enabled headphone service. Other accessibility services were preserved.'
        ;;
    disable)
        if [[ "$found" == false ]]; then
            echo 'Headphone service is already disabled.'
            exit 0
        fi
        if ((${#kept[@]})); then
            joined="$(IFS=:; echo "${kept[*]}")"
            "$adb_bin" -s "$serial" shell settings put secure enabled_accessibility_services "$joined"
        else
            "$adb_bin" -s "$serial" shell settings delete secure enabled_accessibility_services
        fi
        echo 'Disabled headphone service. Other accessibility services were preserved.'
        ;;
    status)
        if [[ "$found" == true ]]; then
            echo 'Headphone service is listed as enabled.'
        else
            echo 'Headphone service is not enabled.'
        fi
        if "$adb_bin" -s "$serial" shell dumpsys accessibility | grep -Fq 'Philips headphone volume keys'; then
            echo 'Headphone service is bound for the current user.'
        else
            echo 'Headphone service is not bound for the current user.'
        fi
        ;;
    *)
        echo 'Usage: accessibility.sh enable|disable|status <adb-serial>' >&2
        exit 2
        ;;
esac
