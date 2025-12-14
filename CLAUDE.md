# Spryte - iOS 26 Icon Preview Tool

This document provides context for Claude Code when working on this project.

## What This App Does

Spryte is a **homescreen icon preview tool** for iOS 26. Its primary purpose is to let designers and developers see how their Icon Composer icons will actually look on a real device's homescreen with iOS 26's Liquid Glass effects.

### The Problem It Solves

iOS 26 introduced a new icon format (`.icon` bundles created in Icon Composer) with dynamic Liquid Glass rendering. These icons look different on the actual homescreen than they do in Icon Composer or Xcode previews. Spryte lets you:

1. **Import icons** from Icon Composer
2. **Preview all 6 renditions** (Default, Dark, Clear Light/Dark, Tinted Light/Dark) in-app
3. **Set any icon as the app icon** to see it on the real homescreen
4. **Organize icons in sections** for comparing variations (e.g., "Consumer", "Dasher/Default", "Dasher/Inverted")

### Typical Workflow

1. Designer creates icon variations in Icon Composer
2. Drops `.icon` files into `Icons to Import/` folder (organized by section)
3. Builds Spryte - import script generates previews automatically
4. Opens Spryte on device, browses icons by section
5. Taps an icon to set it as the app icon
6. Goes to homescreen to see how it actually renders with Liquid Glass

## Key Insight: iOS 26 Icon Bundles

**Important:** iOS 26 `.icon` bundles work differently than traditional asset catalog icons.

- `.icon` files are **folder bundles** created by Icon Composer (not image files)
- They must be in the **Resources build phase**, NOT inside `Assets.xcassets`
- Xcode's `actool` processes them at build time from the Resources phase
- The file type in Xcode is `folder.iconcomposer.icon`

**Do NOT:**
- Put `.icon` files inside the asset catalog
- Try to use `.appiconset` folders for Liquid Glass icons
- Assume traditional icon workflows apply

**Do:**
- Keep `.icon` files at project root level
- Add them to the Spryte target (Resources build phase)
- Reference them by filename (without `.icon` extension) in code

## Architecture

### Key Files

| File | Purpose |
|------|---------|
| `Spryte/IconManager.swift` | Manages icon loading, sections, and switching |
| `Spryte/Views/IconsTab.swift` | Icon picker UI with sectioned grid |
| `Spryte/icons_manifest.json` | Maps icons to sections (auto-generated) |
| `Scripts/import_icons.sh` | Automated icon import and PNG generation |

### Icon System Components

```
Project Root/
├── *.icon                      # Icon Composer bundles (added to Resources)
├── Icons to Import/            # Source icons organized by section
│   ├── Consumer/
│   │   └── *.icon
│   └── Dasher/
│       ├── Default/
│       │   └── *.icon
│       └── Inverted/
│           └── *.icon
├── Spryte/
│   ├── Icon Source/            # Generated preview PNGs
│   │   └── {IconName} Exports/
│   │       └── {IconName}-iOS-{Style}-1024x1024@1x.png
│   └── icons_manifest.json     # Section/icon mapping
└── Scripts/
    └── import_icons.sh         # Build phase script
```

## How Icon Switching Works

### 1. Build Time
- `import_icons.sh` runs as first build phase
- Scans `Icons to Import/` for `.icon` files
- Uses `ictool` to export 6 PNG renditions per icon
- Copies `.icon` files to project root
- Generates `icons_manifest.json` with section groupings

### 2. Runtime
- `IconManager` loads manifest and discovers PNG previews in bundle
- Groups icons into `IconSection` objects based on manifest
- `IconsTab` displays sections with headers and icon grids
- Tapping an icon calls `setAlternateIconName()` with the icon name

### 3. Icon Name Resolution
- Primary icon (`Spryte`): Pass `nil` to `setAlternateIconName()`
- Alternate icons: Pass exact `.icon` filename without extension
- Names must match between `.icon` file, PNG exports, and manifest

## Build Settings

Critical settings in `project.pbxproj`:

```
ASSETCATALOG_COMPILER_APPICON_NAME = Spryte           # Primary icon
ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = ...   # Space-separated alternates
ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS = YES
ENABLE_USER_SCRIPT_SANDBOXING = NO                    # Required for import script
```

## ictool Reference

Location: `/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool`

Export command:
```bash
ictool input.icon \
    --export-image \
    --output-file output.png \
    --platform iOS \
    --rendition Default \  # or Dark, ClearLight, ClearDark, TintedLight, TintedDark
    --width 1024 \
    --height 1024 \
    --scale 1
```

## Adding New Icons

### Automated (Recommended)
1. Place `.icon` files in `Icons to Import/` (use subfolders for sections)
2. Build project - the import script automatically:
   - Generates 6 preview PNGs per icon
   - Copies `.icon` files to project root
   - Adds new `.icon` files to Xcode project (PBXFileReference, PBXBuildFile, Resources)
   - Updates `icons_manifest.json` with sections
3. That's it - fully automated!

### Manual
1. Export 6 PNGs from Icon Composer following naming pattern
2. Place in `Spryte/Icon Source/{IconName} Exports/`
3. Add `.icon` to project root and Xcode Resources
4. Update `icons_manifest.json` if using sections

## Common Issues & Lessons Learned

### Error 3328 - "The requested app icon is not available"

This was the original issue that led to building this app. The error occurs when `setAlternateIconName()` can't find the icon.

**Root Cause:** The `.icon` file must be added to the **Resources build phase**, not just present in the project.

**How to verify:**
1. Select the `.icon` file in Xcode
2. Check File Inspector → Target Membership → Spryte is checked
3. Check Build Phases → Copy Bundle Resources contains the `.icon` file

**What DOESN'T cause this error:**
- Spaces in icon names (we initially thought this was the issue, but it wasn't)
- The icon name in `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` being wrong

### Error 35 - "Resource temporarily unavailable"

**This is NOT a code problem.** It's an iOS system state issue.

**Fix:** Reboot the device. Nothing else works.

This error appears randomly when iOS gets into a bad state with icon switching. We spent time debugging code when the actual fix was just rebooting.

### Sandbox Blocking Import Script

**Symptom:** Build fails with `deny(1) file-read-data` on the import script.

**Cause:** `ENABLE_USER_SCRIPT_SANDBOXING = YES` in build settings blocks the run script from accessing project files.

**Fix:** Set `ENABLE_USER_SCRIPT_SANDBOXING = NO` in both Debug and Release configurations. Already done in this project.

### Duplicate PNG Build Errors

**Symptom:** "Multiple commands produce" errors for PNG files.

**Cause:** Two copies of the same PNG exist, typically from mixing old manual exports with new automated exports:
- `Icon Source/Spryte Exports/Spryte-iOS-Default-1024x1024@1x.png`
- `Icon Source/Spryte/Spryte Exports/Spryte-iOS-Default-1024x1024@1x.png` (nested - wrong!)

**Fix:** Delete any nested folders. Structure should be flat:
```
Icon Source/
├── IconName Exports/     ✓ Correct
│   └── *.png
└── IconName/             ✗ Delete these nested folders
    └── IconName Exports/
        └── *.png
```

### Icons Not Showing in Picker

**Check in order:**
1. PNG files exist in `Spryte/Icon Source/{IconName} Exports/`
2. PNG naming matches exactly: `{IconName}-iOS-{Style}-1024x1024@1x.png`
3. `icons_manifest.json` includes the icon in a section
4. Clean build folder and rebuild (Cmd+Shift+K, then Cmd+B)

### Icon Shows in Picker But Won't Set

If tapping an icon shows error 3328:
- The preview PNGs are working (that's why you see it)
- The `.icon` file is missing from Resources build phase
- Add the `.icon` file to Xcode and ensure it's in the Spryte target

## Data Flow

```
Icons to Import/          import_icons.sh           Bundle
     *.icon          ──────────────────────►    *.icon (Resources)
        │                                       *.png (Icon Source)
        │                                       icons_manifest.json
        ▼
   Folder structure  ──►  icons_manifest.json  ──►  IconManager.sections
                                                         │
                                                         ▼
                                                    IconsTab UI
                                                         │
                                                         ▼
                                               setAlternateIconName()
```

## Testing Changes

```bash
# Build from command line
xcodebuild -scheme Spryte -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Run import script manually
cd "/Users/john/Documents/Icon Test/Spryte"
./Scripts/import_icons.sh
```

## File Patterns

- Icon bundles: `*.icon` (actually directories)
- Preview PNGs: `{IconName}-iOS-{Style}-1024x1024@1x.png`
- Styles: `Default`, `Dark`, `ClearLight`, `ClearDark`, `TintedLight`, `TintedDark`
