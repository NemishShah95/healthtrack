# Data Safety

Your manual logs (meals, water, supplements, check-ins) exist **only on your iPhone**. Read this before reinstalling or upgrading.

## 1. What lives in Apple Health (HealthKit)

Sleep, heart rate, resting heart rate, HRV, steps, workouts, active energy, distance, exercise time, and weight/oxygen saturation if available.
HealthTrack only **reads** these. They stay in Apple Health no matter what happens to HealthTrack, so they never need backing up from here.

## 2. What lives in HealthTrack (SwiftData, on the iPhone)

Meals and food entries, saved meals and favourite foods, water logs, supplements, supplement schedules and logs, daily check-ins, your goals and settings, and the app-refresh dates.
These exist nowhere else unless you export a backup.

## 3. What happens during a normal refresh from Xcode

Pressing **Run** in Xcode with your iPhone selected re-signs the app and installs the new copy **over** the existing one. iOS keeps the app's data container, so your logs stay exactly as they were. This is the same thing that happens when any app updates from the App Store.

## 4. Why the bundle identifier must never change

iOS keeps each app's data by its bundle identifier: **`com.nemishshah.healthtrack`**.
Change it and iOS sees a brand-new app with an empty database. Your old data isn't migrated; it stays with the old identifier, and you can only reach it by changing the identifier back.

## 5. Why you must not delete the app

Deleting an app from the iPhone **permanently deletes its data container**. A refresh never requires deleting the app. If Xcode reports an error, fix the error; don't delete the app.

## 6. How to export a backup

Settings → **Data & Backup** → **Export JSON** (full restorable backup) or **Export CSV** (for spreadsheets). Save the file somewhere off the phone, such as AirDrop to your Mac, or iCloud Drive or Files.
Backups contain personal health information. Don't commit them to git (the repository ignores `HealthTrack-Export-*` files).

## 7. How to restore

Settings → Data & Backup → **Import JSON backup** (arrives in M15). Import adds records that aren't already present (matched by ID), so importing the same file twice doesn't duplicate anything. A backup from a newer HealthTrack version is refused rather than partially imported.

## 8. What could cause data loss

- Deleting the HealthTrack app from the iPhone
- Changing the bundle identifier
- Erasing or replacing the iPhone without an iPhone backup or a HealthTrack export
- A careless database schema change in a future version (see below)
- Letting the app expire is **not** data loss: it stops launching, but the data stays. Refreshing from Xcode brings it back.

## 9. Safe upgrade procedure

For you, before installing a new version:

1. Export a JSON backup.
2. Install with **Run** in Xcode, over the existing app. Don't delete it first.
3. Open HealthTrack and check that today's and last week's entries are there.

For the engineer, before changing any SwiftData model after V1:

1. Assess the migration impact. Never rename or remove a persisted field casually.
2. Add a new `VersionedSchema` and a `SchemaMigrationPlan` stage.
3. Test the migration against a populated database.
4. Verify that record counts before and after are identical.
5. Only then merge the change.
