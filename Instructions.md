# Adding App Icons to Spryte

This guide explains how to add new alternate app icons using Icon Composer (.icon files) for iOS 26's Liquid Glass effects.

## Requirements

- Xcode 26+
- Icon Composer (included with Xcode 26)

## Quick Start (Automated)

The easiest way to add icons is using the automated import system:

1. **Create icons in Icon Composer** and save them as `.icon` files
2. **Organize in `Icons to Import/`** folder using subfolders for sections:
   ```
   Icons to Import/
   ├── Consumer/
   │   ├── Consumer 01 Default Gradient.icon
   │   └── Consumer 02 Soft Gradient.icon
   ├── Dasher/
   │   ├── Default/
   │   │   └── Dasher 01.icon
   │   └── Inverted/
   │       └── Dasher 01.icon
   └── My Custom Icons/
       └── MyIcon.icon
   ```
3. **Build the project** - The import script runs automatically and:
   - Generates preview PNGs for all 6 styles
   - Copies `.icon` files to project root
   - Updates `icons_manifest.json` with sections
4. **Add new `.icon` files to Xcode** (one-time per icon):
   - Drag new `.icon` files from project root into Xcode
   - Check "Copy items if needed" and select target **Spryte**

## Folder Structure = Sections

Icons are grouped in the UI based on their folder location:

| Folder Path | Section Name |
|-------------|--------------|
| `Icons to Import/Consumer/*.icon` | Consumer |
| `Icons to Import/Dasher/Default/*.icon` | Dasher/Default |
| `Icons to Import/Dasher/Inverted/*.icon` | Dasher/Inverted |
| `Icons to Import/*.icon` | Uncategorized |

## Manual Process

If you prefer manual control:

### Step 1: Create the Icon

1. Open **Icon Composer** (search in Spotlight)
2. Design your icon with layers, translucency, and glass effects
3. Save as `YourIconName.icon`

### Step 2: Export Preview PNGs

Use Icon Composer's export or run manually:

```bash
ICTOOL="/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"

for STYLE in Default Dark ClearLight ClearDark TintedLight TintedDark; do
    "$ICTOOL" YourIcon.icon \
        --export-image \
        --output-file "YourIcon-iOS-${STYLE}-2048x2048@1x.png" \
        --platform iOS \
        --rendition "$STYLE" \
        --width 2048 --height 2048 --scale 1
done
```

### Step 3: Add Files to Project

1. Copy `.icon` file to project root
2. Place PNGs in `Spryte/Icon Source/YourIcon Exports/`
3. Drag `.icon` file into Xcode, add to Spryte target
4. Update `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` if needed

## How It Works

- **Build Phase**: `Scripts/import_icons.sh` runs before each build
- **Change Detection**: Only regenerates when icons change (hash-based)
- **Preview Discovery**: `IconManager.swift` scans for PNGs matching `{Name}-iOS-{Style}-2048x2048@1x.png`
- **Section Support**: Reads `icons_manifest.json` to group icons
- **Icon Switching**: Uses `UIApplication.shared.setAlternateIconName()` at runtime
- **Icon Shape**: iOS 26 icons use a squircle (continuous corner curve) with corner radius ≈ 44% of icon width

## Build Settings Reference

| Setting | Purpose |
|---------|---------|
| `ASSETCATALOG_COMPILER_APPICON_NAME` | Primary icon (currently `Default`) |
| `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` | Space-separated alternate icon names |
| `ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS` | Include all `.icon` files in Resources |

> **⚠️ WARNING:** Never delete `Default.icon` from the project root. This is the primary app icon required for builds. If deleted, the build will fail with "None of the input catalogs contained a matching app icon set named Default".

## Troubleshooting

### Nuclear Reset (When Icons Won't Switch)

If icon switching fails persistently, perform these steps **in this exact order**:

1. **Clean Build Folder** in Xcode: `Product > Clean Build Folder` (⇧⌘K)
2. **Quit Xcode** completely
3. **Delete the app** from your device
4. **Reboot your device**
5. Reopen Xcode and rebuild to device

This order is critical - the device caches icon state that persists until reboot.

### Diagnostic Checks

When icons fail to switch, verify these in the **device build** (not simulator):

```bash
# Check Info.plist has alternate icons registered
plutil -p /path/to/Debug-iphoneos/Spryte.app/Info.plist | grep -A 50 CFBundleAlternateIcons

# Check Assets.car contains compiled icons
xcrun --sdk iphoneos assetutil --info /path/to/Spryte.app/Assets.car | grep -i "Name"

# Verify .icon files exist at project root
ls -la *.icon
```

**Expected Info.plist structure:**
```
"CFBundleAlternateIcons" => {
  "YourIconName" => {
    "CFBundleIconName" => "YourIconName"
  }
}
```

### Error 3328 (Icon Not Registered)

The icon name isn't registered. Check:
- The `.icon` file is in the project and added to Resources build phase
- The name matches exactly (case-sensitive)
- Run `plutil -p` on the **device build** Info.plist to verify the icon is listed
- Simulator and device builds can differ - always check the device build

### Error 35 (Resource temporarily unavailable)

This is an iOS system state issue. Follow the **Nuclear Reset** steps above.

### Icons not showing in picker

Ensure preview PNGs exist with the correct naming pattern:
`{IconName}-iOS-{Style}-2048x2048@1x.png`

### Import script not running

Check Build Phases for "Import Icons" run script. Should be first in the list.

### Simulator vs Device Mismatch

The simulator and device builds are separate. If icons work on simulator but not device (or vice versa):
- Clean build folder
- Build specifically for your target (device or simulator)
- Check the correct Info.plist: `Debug-iphoneos` for device, `Debug-iphonesimulator` for simulator
