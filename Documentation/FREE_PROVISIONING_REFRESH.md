# Refreshing HealthTrack (about every 6 days)

Free Apple signing lasts about 7 days. HealthTrack suggests a refresh on day 6 and warns you 2 days ahead on its Today screen.

1. In HealthTrack, export a backup: Settings → Data & Backup → **Export JSON**.
2. Connect your iPhone to your personal Mac.
3. Open **HealthTrack.xcodeproj** in Xcode.
4. Check that the same **Personal Team** is selected (target → Signing & Capabilities). It must be the same Apple Account as every previous install.
5. Confirm the bundle identifier is still **`com.nemishshah.healthtrack`**. It must **not** have changed.
6. Select your iPhone as the run destination.
7. Press **Run** (▶).
8. Let Xcode reinstall and re-sign over the existing app.
9. **Do NOT delete HealthTrack first.** Deleting it erases your logs.
10. Open HealthTrack and confirm your data is still there.
11. Confirm the Apple Health numbers still show (sleep, steps).
12. HealthTrack detects the refresh by itself and resets the next suggested refresh date.

If the app has already stopped opening, nothing is lost. Do steps 2–10 and it will open again with your data.

## If the expiry date doesn't move

Xcode reuses the signing profile it already has, even when that profile expires in a few hours, and it can't make a new one if it has been signed out of your Apple Account. This happened on 2026-11-07. To check and fix:

1. **Xcode → Settings → Accounts**: your Apple Account must be listed. If not, sign in again (yourself, in Xcode's window).
2. After Run, check the expiry in HealthTrack → Settings → App Installation → **Signing expires**. It should be about 7 days away.
3. If it isn't, quit Xcode, move the old profile out of `~/Library/Developer/Xcode/UserData/Provisioning Profiles/` (keep it somewhere until the new one works), and press Run again. Xcode then asks Apple for a new one.
