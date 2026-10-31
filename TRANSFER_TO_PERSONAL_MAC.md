# Installing HealthTrack on Your iPhone (Personal Mac)

The work Mac can't connect to your iPhone, so the first install and every refresh happen on your personal Mac, using Apple's free "Personal Team". No paid developer account or TestFlight is needed.

## One-time setup

1. **Get the project onto the personal Mac.** Clone it from your personal GitHub account, or copy the whole folder (including the hidden `.git` folder) with a USB drive or AirDrop.
2. **Install Xcode** from the Mac App Store and open it once. Accept the license and install the iOS platform when asked.
3. **Sign in:** Xcode → Settings → Accounts → **+** → Apple Account. Sign in yourself; never share the password or 2FA code with anyone.
4. Open **`HealthTrack.xcodeproj`**.
5. Select the **HealthTrack** target → **Signing & Capabilities**:
   - Team: **_Your Name_ (Personal Team)**
   - Bundle Identifier: **`com.nemishshah.healthtrack`**. Confirm it is exactly this, and never change it.
   - HealthKit capability: should already be listed.
6. **Connect your iPhone** with a cable and unlock it. Tap **Trust** on the phone when asked.
7. **Enable Developer Mode** if Xcode asks: iPhone Settings → Privacy & Security → Developer Mode → On, then restart the phone when prompted.
8. In Xcode's toolbar, select **your iPhone** as the run destination.
9. Press **Run** (▶).
10. The first time only, the phone may refuse to open an app from an "untrusted developer". On the iPhone, go to Settings → General → VPN & Device Management → your Apple Account → **Trust**, then press Run again.
11. In HealthTrack, **allow Apple Health access** (turn on all categories) and **allow notifications**.
12. Compare a few numbers with the Apple Health app (last night's sleep, today's steps) to confirm real data comes through.

## Every ~6 days

Follow [Documentation/FREE_PROVISIONING_REFRESH.md](Documentation/FREE_PROVISIONING_REFRESH.md). The app reminds you on its Today screen.

## Which iPhones

Any iPhone running iOS 17 or later, including iPhone 16 Pro, 17 and 17 Pro.

## Installing it for someone else

Each phone keeps its own data, so several people can use HealthTrack, each on their own iPhone. There are two ways to install it for someone else:

1. **Free.** They need a Mac with Xcode and their own Apple Account. They change the bundle identifier **once, before their first install**, to their own (e.g. `com.theirname.healthtrack`), because yours is registered to your Personal Team. Then they follow this guide. They have to refresh every 7 days, just like you.
2. **Paid.** You join the Apple Developer Program ($99/year) and invite people through TestFlight. Installs then last 90 days per build and need no Mac on their side.

## Free Personal Team limits

- Apps stop launching about 7 days after the last install from Xcode. Your data is kept; you just need to refresh.
- At most 3 free-provisioned apps per device at a time.
- Don't create new bundle identifiers to work around anything (see [DATA_SAFETY.md](DATA_SAFETY.md)).
