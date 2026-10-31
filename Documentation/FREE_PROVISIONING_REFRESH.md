# Refreshing HealthTrack (about every 6 days)

Free Apple signing lasts about 7 days. HealthTrack suggests a refresh on day 6 and warns you 2 days ahead on its Today screen.

1. In HealthTrack, export a backup: Settings → Data & Backup → **Export JSON**.
2. Connect your iPhone to your personal Mac.
3. Open **HealthTrack.xcodeproj** in Xcode.
4. Check that the same **Personal Team** is selected (target → Signing & Capabilities).
5. Confirm the bundle identifier is still **`com.nemishshah.healthtrack`**. It must **not** have changed.
6. Select your iPhone as the run destination.
7. Press **Run** (▶).
8. Let Xcode reinstall and re-sign over the existing app.
9. **Do NOT delete HealthTrack first.** Deleting it erases your logs.
10. Open HealthTrack and confirm your data is still there.
11. Confirm the Apple Health numbers still show (sleep, steps).
12. HealthTrack detects the refresh by itself and resets the next suggested refresh date.

If the app has already stopped opening, nothing is lost. Do steps 2–10 and it will open again with your data.
