# Spoofy

Spoofy is a free, open-source Mac app that lets you choose a simulated location for a connected iPhone. Pick a spot on the map, search for a place, or choose a popular city such as Tel Aviv, London, or New York.

**Spoofy is an early preview.** Some features and iPhone models still need more testing. See [Limitations](#limitations) before you get started.

## What you need

- A Mac with an Apple silicon chip (M1 or newer) and macOS 13 or newer.
- An iPhone, a compatible USB cable, and the phone's passcode.
- An internet connection for map search and walking directions.

Spoofy runs on your Mac and connects to your iPhone. It isn't an app you install on the iPhone itself.

## Download and open Spoofy

1. Open the [Releases page](https://github.com/Akhilucky/Spoofy/releases) and download **Spoofy-macOS.zip** from the latest preview release.
2. Double-click the downloaded ZIP file to unzip it, then move **Spoofy.app** to your Applications folder.
3. Open Spoofy. macOS may warn that the app is from an unidentified developer: this preview isn't signed with an Apple Developer ID or notarized. If you choose to run it, follow [Apple's instructions for opening an app from an unidentified developer](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unidentified-developer-mh40616/mac).

## Connect your iPhone

1. Connect your iPhone to your Mac with a USB cable and unlock it.
2. If your iPhone asks **Trust This Computer?**, tap **Trust** and enter your passcode. Keep the phone unlocked while setting up.
3. On your iPhone, open **Settings → Privacy & Security**, scroll down to the **Security** section, and look for **Developer Mode**.

### Can't find Developer Mode? Don't worry, we gotchu

1. With your iPhone connected and unlocked, click **Reveal Developer Mode** in Spoofy's **iPhone setup** section. This button asks your iPhone to show the setting; it doesn't turn it on for you.
2. Go back to **Settings → Privacy & Security → Developer Mode** on your iPhone. Turn it on and tap **Restart**.
3. After the phone restarts, unlock it, confirm **Turn On**, and enter your passcode if asked.

Developer Mode reduces some security protections on your iPhone. You can turn it off later in the same Settings screen. If the option still doesn't appear, check the cable and Trust prompt, then see [pymobiledevice3's troubleshooting guide](https://github.com/doronz88/pymobiledevice3/blob/master/docs/guides/troubleshooting.md).

## Choose a location

1. In Spoofy, leave **iOS 17 or newer** checked if your iPhone runs iOS 17 or later. You can check your version on the phone under **Settings → General → About → iOS Version**.
2. Click a place on the map, search for an address, enter coordinates, or choose a city from **Popular cities**.
3. Click **Set location** and wait for the status message. You can select another place and set it again.
4. When you're done, click **Restore real location** and check your location on the phone. If it doesn't return to normal, reconnect and try restoring again, or restart your iPhone.

Spoofy also lets you save places, revisit recently set locations, move in steps, add route points, request walking directions, and import or export a GPX route file. To run a route, add at least two waypoints and click **Start route**. **Stop movement** stops the route but leaves the last simulated location active; use **Restore real location** when finished.

## Limitations

- **Early preview:** Spoofy hasn't been tested across all iPhones and iOS versions. Setup, location changes, and route playback may fail or behave differently on your device.
- **Apple silicon only:** the current download is for M-series Macs. Intel Macs and Windows aren't supported by this release.
- **A Mac is required:** Spoofy uses iPhone developer services through a trusted computer; it isn't a standalone iPhone app.
- **Not every app will accept the simulated location.** A successful Spoofy command doesn't guarantee another app will display or use it.
- **Routes are experimental.** They follow straight lines between points unless you request walking directions. Directions and search need internet access and may not be available everywhere.
- **Unsigned preview:** macOS may warn about the download. The app isn't notarized or signed with an Apple Developer ID.
- **Location stays simulated until restored:** stopping a route doesn't restore your real location. Verify the result on your phone after restoring.

If a command fails, check the status and details shown at the bottom of Spoofy. Make sure the phone is connected, unlocked, trusted, and has Developer Mode enabled. For additional device-specific help, see [pymobiledevice3 troubleshooting](https://github.com/doronz88/pymobiledevice3/blob/master/docs/guides/troubleshooting.md).

## Build from source

Building requires an Apple silicon Mac, Xcode command-line tools, Python 3.12, and internet access to install dependencies. Run `./build.sh`. The downloadable ZIP is created at `dist/Spoofy-macOS.zip`. The script bundles the Python backend with PyInstaller without Developer ID signing; the build isn't notarized. GitHub Actions builds a preview release when a `v*` tag is pushed; a manually started workflow builds an artifact without creating a release.

## License

MIT. Spoofy uses [pymobiledevice3](https://github.com/doronz88/pymobiledevice3) and other dependencies under their respective licenses.
