# Spryte TestFlight Deployment Guide

## Quick Deploy

Once set up, deploying is a single command:

```bash
./Scripts/deploy_testflight.sh
```

Or via Claude Code:
```
/deploy-testflight
```

## App Details

| Field | Value |
|-------|-------|
| App Name | Spryte Icon Preview |
| Bundle ID | com.doordash.spryte |
| App Store Connect ID | 6756588381 |
| Team ID | K2XB837E84 |
| API Key ID | TA8277P6W3 |

**Links:**
- [App Store Connect](https://appstoreconnect.apple.com/apps/6756588381/testflight)
- [TestFlight (web)](https://beta.itunes.apple.com/v1/app/6756588381)

## First-Time Setup (Already Done)

These steps have already been completed for this project:

### 1. App Store Connect API Key

The API key is stored at:
```
~/.appstoreconnect/private_keys/AuthKey_TA8277P6W3.p8
```

To create a new key (if needed):
1. Go to [App Store Connect API Keys](https://appstoreconnect.apple.com/access/integrations/api)
2. Click **+** to generate a new key
3. Select **Admin** or **App Manager** role
4. Download the `.p8` file immediately (only available once)
5. Move to `~/.appstoreconnect/private_keys/`

### 2. App Registration

The app "Spryte Icon Preview" is registered in App Store Connect with bundle ID `com.doordash.spryte`.

### 3. Internal Tester Group

The "DoorDash Design" internal tester group is set up. Internal testers automatically receive all builds.

## Deployment Process

### What the Script Does

1. **Increments build number** in project.pbxproj
2. **Archives** the app (~1 minute)
3. **Exports IPA** for App Store distribution
4. **Uploads** to TestFlight (~30 seconds)

### After Upload

- Build takes **5-15 minutes** to process in App Store Connect
- Internal testers (DoorDash Design group) automatically get access
- No beta review required for internal testing

### Script Options

```bash
# Full deployment
./Scripts/deploy_testflight.sh

# Build only, don't upload
./Scripts/deploy_testflight.sh --dry-run

# Verbose output (show full xcodebuild logs)
./Scripts/deploy_testflight.sh --verbose
```

## Build Artifacts

After a build, artifacts are stored in:
```
build/
├── Spryte.xcarchive    # Xcode archive
└── export/
    └── Spryte.ipa      # Uploadable IPA (~493MB)
```

## Troubleshooting

### "Cannot determine Apple ID from Bundle ID"

The app isn't registered in App Store Connect. This should already be done, but if you see this error:
1. Go to [App Store Connect Apps](https://appstoreconnect.apple.com/apps)
2. Click **+** → **New App**
3. Use bundle ID: `com.doordash.spryte`

### "API key file not found"

```bash
# Check if key exists
ls ~/.appstoreconnect/private_keys/

# Should show: AuthKey_TA8277P6W3.p8
```

### Build not appearing in TestFlight

1. Wait 5-15 minutes for processing
2. Check [App Store Connect](https://appstoreconnect.apple.com/apps/6756588381/testflight) for build status
3. Force quit and reopen TestFlight app
4. Ensure you're signed in with the correct Apple ID

### "Archive failed"

Run with verbose mode to see errors:
```bash
./Scripts/deploy_testflight.sh --verbose --dry-run
```

## Version Management

- **Marketing Version** (1.0, 1.1, etc.): Update manually in Xcode or project.pbxproj
- **Build Number** (1, 2, 3, etc.): Auto-incremented by the script

To bump marketing version:
```bash
# Find and update MARKETING_VERSION in project.pbxproj
sed -i '' 's/MARKETING_VERSION = 1.0;/MARKETING_VERSION = 1.1;/g' Spryte.xcodeproj/project.pbxproj
```

## Security

- API key is stored locally at `~/.appstoreconnect/private_keys/`
- Never commit `.p8` files to version control
- The key can be revoked anytime from App Store Connect
