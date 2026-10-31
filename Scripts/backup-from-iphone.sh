#!/bin/sh
# Copies HealthTrack's database off the connected iPhone into
#   ~/Documents/HealthTrack Backups/<date_time>/
# Works for Xcode-installed builds, over USB or Wi-Fi, from any Mac paired with the phone.
# For the cleanest copy, close HealthTrack on the phone first.
# Usage: Scripts/backup-from-iphone.sh [device-name-or-id]
#
# ponytail: a raw copy of the SQLite files is the second safety net; the restorable backup is still
# the app's own JSON export (Settings → Data & Backup). Raw files can be pushed back with
# `xcrun devicectl device copy to` if ever needed.
set -eu

BUNDLE=com.nemishshah.healthtrack
DEVICE="${1:-}"
if [ -z "$DEVICE" ]; then
  JSON=$(mktemp)
  xcrun devicectl list devices --json-output "$JSON" >/dev/null 2>&1
  DEVICE=$(python3 -c '
import json, sys
devices = json.load(open(sys.argv[1]))["result"]["devices"]
print(next((d["identifier"] for d in devices if d.get("hardwareProperties", {}).get("reality") == "physical"), ""))
' "$JSON")
  rm -f "$JSON"
fi
[ -n "$DEVICE" ] || { echo "No iPhone found. Connect it (or join the same Wi-Fi) and unlock it." >&2; exit 1; }

OUT="$HOME/Documents/HealthTrack Backups/$(date +%Y-%m-%d_%H%M)"
mkdir -p "$OUT"
for f in HealthTrack.store HealthTrack.store-wal HealthTrack.store-shm; do
  xcrun devicectl device copy from --device "$DEVICE" --domain-type appDataContainer \
    --domain-identifier "$BUNDLE" --source "Library/Application Support/$f" --destination "$OUT/$f" >/dev/null
done
echo "Backed up HealthTrack to: $OUT"
ls -lh "$OUT" | tail -n +2
