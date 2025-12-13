# Adding App Icons to Spryte

This guide explains how to add new alternate app icons using Icon Composer (.icon files) for iOS 26's Liquid Glass effects.

## Requirements

- Xcode 26+
- Icon Composer (included with Xcode 26)
- Icons must use **no spaces** in filenames

## Step 1: Create the Icon in Icon Composer

1. Open **Icon Composer** (search in Spotlight or find in Xcode's Developer Tools)
2. Design your icon with layers, translucency, and glass effects
3. Save the file as `YourIconName.icon` (e.g., `MyNewIcon.icon`)
4. Export using File > Export. Ensure you select 'Appearance All'. Then Export... This will generate all the previews in a folder correctly for the steps below.  


## Step 2: Add the .icon File to the Project

1. Drag the `.icon` file into the **project root** in Xcode (same level as `Spryte.icon`)
2. When prompted:
   - Check "Copy items if needed"
   - Select target: **Spryte**
   - This adds it to the Resources build phase automatically

## Step 3: Add Preview Images for the Icon Picker UI

The app's icon picker uses PNG exports for previews. Create the folder structure:

```
Spryte/Icon Source/
└── YourIconName/
    └── YourIconName Exports/
        ├── YourIconName-iOS-Default-1024x1024@1x.png
        ├── YourIconName-iOS-Dark-1024x1024@1x.png
        ├── YourIconName-iOS-ClearLight-1024x1024@1x.png
        ├── YourIconName-iOS-ClearDark-1024x1024@1x.png
        ├── YourIconName-iOS-TintedLight-1024x1024@1x.png
        └── YourIconName-iOS-TintedDark-1024x1024@1x.png
```

To export these PNGs from Icon Composer:
1. Open your `.icon` file in Icon Composer
2. Use **File > Export** for each variant
3. Name them following the pattern above exactly

## Step 4: Update Build Settings (if not auto-discovered)

If the icon doesn't appear, add it to the alternate icons list:

1. Select the **Spryte** project in Xcode
2. Select the **Spryte** target
3. Go to **Build Settings**
4. Search for `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`
5. Add your icon name (without `.icon` extension), separated by spaces:
   ```
   DoorDashConsumerApp MyNewIcon AnotherIcon
   ```

## Naming Rules

| Do | Don't |
|---|---|
| `MyNewIcon.icon` | `My New Icon.icon` |
| `DoorDashApp.icon` | `DoorDash App.icon` |
| `Icon2024.icon` | `Icon 2024.icon` |

Spaces in icon names cause Xcode to split them into multiple entries, breaking icon switching.

## How It Works

- **Primary Icon**: Set via `ASSETCATALOG_COMPILER_APPICON_NAME` (currently `Spryte`)
- **Alternate Icons**: Listed in `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`
- **Icon Switching**: Uses `UIApplication.shared.setAlternateIconName()` at runtime
- **Preview Discovery**: `IconManager.swift` scans for PNGs matching the naming pattern

## Troubleshooting

### Error 3328
The icon name isn't registered. Check:
- The `.icon` file is in the project and target
- The name matches exactly (case-sensitive)
- No spaces in the filename

### Error 35 (Resource temporarily unavailable)
Reboot your device. This is an iOS system state issue.

### Icons not showing in picker
Ensure preview PNGs exist in `Icon Source/YourIconName/YourIconName Exports/` with the correct naming pattern.
