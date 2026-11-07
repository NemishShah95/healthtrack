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

# Prove the copy opens (idea from Helios's restore drill). Checked on a scratch copy, because opening a
# SQLite database folds the -wal file into it and the backup itself should stay exactly as copied.
CHECK=$(mktemp -d)
trap 'rm -rf "$CHECK"' EXIT
cp "$OUT"/HealthTrack.store* "$CHECK/"
DB="$CHECK/HealthTrack.store"
if [ "$(sqlite3 "$DB" 'PRAGMA integrity_check;' 2>&1)" != "ok" ]; then
  echo "WARNING: this copy failed its integrity check. Keep the previous backup and try again with HealthTrack closed." >&2
  exit 2
fi
sqlite3 -separator ' ' "$DB" "SELECT 'Check: OK.', (SELECT count(*) FROM ZMEAL), 'meals,', (SELECT count(*) FROM ZWATERENTRY), 'water,',
  (SELECT count(*) FROM ZPROTEINENTRY), 'protein,', (SELECT count(*) FROM ZGYMSESSION), 'gym sessions,',
  (SELECT count(*) FROM ZSUPPLEMENTLOG), 'vitamin logs,', (SELECT count(*) FROM ZDAILYCHECKIN), 'check-ins';"
