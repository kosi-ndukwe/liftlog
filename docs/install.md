# Installing LiftLog on your iPhone

LiftLog isn't on the App Store; you install it straight from this Mac with Xcode. Once set up, reinstalling after a change is one command.

## One-time setup (about 10 minutes)

1. **Sign Xcode into your Apple ID.** Xcode → Settings… → Accounts → **+** → Apple ID. A free Apple ID is enough. Xcode makes a "Personal Team" for it.
   - With a free account the app stops opening after **7 days** and you reinstall it (step "Reinstall" below). A paid Apple Developer account ($99/yr) makes it last a year.
2. **Plug the iPhone into the Mac** with a cable and unlock it. Tap **Trust** on the phone when asked, and **Allow** on the Mac.
3. **Turn on Developer Mode on the iPhone**: Settings → Privacy & Security → Developer Mode → on. The phone restarts.
4. **Pick your team in the project**: open `LiftLog.xcodeproj` in Xcode, select the **LiftLog** target → **Signing & Capabilities**, tick *Automatically manage signing*, and choose your name under **Team**. Xcode creates the signing certificate and profile, including the HealthKit capability that's already in the project.
5. **Choose your phone** in the device menu at the top of Xcode (next to "LiftLog") and press **Run** (⌘R). The first time, the phone says the developer isn't trusted: Settings → General → VPN & Device Management → your Apple ID → **Trust**. Run again.

## Reinstall after a change (or after 7 days)

With the phone plugged in:

```bash
xcodebuild -project LiftLog.xcodeproj -scheme LiftLog -destination 'id=00008140-00162CDC3C6A801C' -allowProvisioningUpdates -allowProvisioningDeviceRegistration -derivedDataPath build build
```

```bash
xcrun devicectl device install app --device 00008140-00162CDC3C6A801C build/Build/Products/Debug-iphoneos/LiftLog.app
```

(`00008140-00162CDC3C6A801C` is your iPhone's identifier; `xcrun devicectl list devices` shows it.)

Or just press Run in Xcode. Your workouts stay on the phone; reinstalling over the top keeps the database.

## Getting your Fitbod history onto the phone

Export the CSV from Fitbod (Settings → Export Workout Data), save it to **Files** on the phone (iCloud Drive is easiest), then in LiftLog: Settings → **Import Fitbod CSV** and pick the file. It takes about 20 seconds for five years of workouts. Importing again later only adds new workouts.

## Apple Health

Settings → Apple Health has three switches (steps, heart rate from WHOOP, save workouts). The first one you turn on asks for Health access. If you refuse and change your mind: Health app → your picture → Apps → LiftLog.

## If something goes wrong

- **"Untrusted Developer"** on the phone: Settings → General → VPN & Device Management → Trust.
- **"Could not launch"** / Developer Mode: step 3 above.
- **"No signing certificate"**: step 1 and 4 above; make sure a Team is chosen.
- **App stops opening after a week**: free-account limit; reinstall.
