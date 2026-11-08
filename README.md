# Spoofy

Spoofy is an open-source Mac companion for simulating an iPhone's location through developer services. Select a location on a map, search for an address, or pick a popular city. Save places, revisit recent locations, create walking routes, and import or export GPX files.

**Status: early preview.** Device support and route playback have not been fully tested. A successful command doesn't guarantee every app will use the simulated location.

## Download

Get the latest preview from this repository's **Releases** page. The current build targets Apple silicon Macs running macOS 13 or newer. Unzip Spoofy and move it to Applications. The preview is not notarized or signed with an Apple Developer ID, so macOS may warn when opening it; see [Apple's instructions for opening an app from an unidentified developer](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unidentified-developer-mh40616/mac). Only run a release you trust.

## Connect an iPhone

1. Connect and unlock the iPhone, and accept **Trust This Computer** if asked.
2. In Spoofy, click **Reveal Developer Mode** if the setting is missing.
3. On the iPhone, go to **Settings → Privacy & Security → Developer Mode**, turn it on, restart, and confirm after unlocking. Developer Mode reduces some device security protections.
4. Select the correct iOS version in Spoofy, pick a location, and click **Set location**. Click **Restore real location** when finished and verify the result on your phone.

Apple Maps directions and search require network access. Routes and location simulations may not behave consistently on all iOS versions. If the device isn't recognized, consult [pymobiledevice3 troubleshooting](https://github.com/doronz88/pymobiledevice3/blob/master/docs/guides/troubleshooting.md). An iOS app alone cannot set system-wide location; Spoofy runs on a Mac and talks to the phone's developer services.

## Build

Requires Apple silicon macOS, Xcode command-line tools, Python 3.12, and internet access to install dependencies. Run `./build.sh`. The result is `dist/Spoofy-macOS.zip`; the script bundles the Python backend with PyInstaller without Developer ID signing. The build is not notarized. GitHub Actions builds a preview release when a `v*` tag is pushed; `workflow_dispatch` builds an artifact without creating a release.

## License

MIT. Spoofy uses [pymobiledevice3](https://github.com/doronz88/pymobiledevice3) and other dependencies under their respective licenses.
