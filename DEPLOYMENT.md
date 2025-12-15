# Spryte TestFlight Deployment Guide

This guide explains how to deploy Spryte to TestFlight using the automated deployment script.

## Prerequisites

### 1. App Store Connect API Key

You need an App Store Connect API key to upload builds:

1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Click **Users and Access** in the top menu
3. Select the **Integrations** tab
4. Click **App Store Connect API**
5. Click the **+** button to create a new key
6. Give it a name (e.g., "Spryte Deployment")
7. Select **Admin** or **App Manager** role
8. Click **Generate**
9. **Download the key immediately** - you can only download it once!
10. Note the **Key ID** (shown in the table)
11. Note the **Issuer ID** (shown at the top of the Keys section)

### 2. Store the API Key

Place your downloaded API key file in the correct location:

```bash
# Create the directory
mkdir -p ~/.appstoreconnect/private_keys

# Move your downloaded key (replace KEY_ID with your actual key ID)
mv ~/Downloads/AuthKey_KEY_ID.p8 ~/.appstoreconnect/private_keys/

# Secure the file
chmod 600 ~/.appstoreconnect/private_keys/AuthKey_*.p8
```

### 3. Set Environment Variables

Add these to your shell profile (`~/.zshrc` or `~/.bashrc`):

```bash
export ASC_API_KEY_ID="YOUR_KEY_ID"
export ASC_API_ISSUER_ID="YOUR_ISSUER_ID"
```

Then reload: `source ~/.zshrc`

## Deployment

### Using the Script

From the project root:

```bash
# Deploy to TestFlight (with env vars set)
./Scripts/deploy_testflight.sh

# Or pass credentials as arguments
./Scripts/deploy_testflight.sh --key-id ABC123 --issuer-id 12345678-1234-1234-1234-123456789012

# Dry run (build but don't upload)
./Scripts/deploy_testflight.sh --dry-run
```

### Using Claude Code

```
/deploy-testflight
```

Or for a dry run:

```
/deploy-testflight --dry-run
```

### What the Script Does

1. **Increments build number** - Automatically bumps `CURRENT_PROJECT_VERSION` in project.pbxproj
2. **Archives the app** - Creates a Release archive for iOS
3. **Exports IPA** - Uses ExportOptions.plist for App Store Connect distribution
4. **Uploads to TestFlight** - Uses App Store Connect API for upload

## Build Artifacts

After a successful build, you'll find:
- Archive: `build/Spryte.xcarchive`
- IPA: `build/export/Spryte.ipa`

## Troubleshooting

### "API key file not found"

Ensure your API key is in the correct location:
```bash
ls -la ~/.appstoreconnect/private_keys/
```

You should see `AuthKey_<YOUR_KEY_ID>.p8`

### "Authentication credentials are missing or invalid"

1. Verify your Key ID and Issuer ID are correct
2. Ensure the API key has the correct role (Admin or App Manager)
3. Check that the key hasn't been revoked in App Store Connect

### "No matching provisioning profile found"

1. Open Xcode and go to **Signing & Capabilities**
2. Ensure **Automatically manage signing** is checked
3. Select your team (K2XB837E84)
4. Let Xcode create/download the provisioning profile

### Build number conflicts

If TestFlight rejects a build due to a duplicate build number:
1. Check current build in App Store Connect
2. Manually update `CURRENT_PROJECT_VERSION` in project.pbxproj to a higher number
3. Re-run the deployment script

## Version Management

- **Marketing Version**: Set in Xcode project settings (`MARKETING_VERSION`)
- **Build Number**: Auto-incremented by the script (`CURRENT_PROJECT_VERSION`)

To bump the marketing version for a new release:
```bash
# In project.pbxproj, find and update:
MARKETING_VERSION = 1.1;  # Change from 1.0 to 1.1
```

## Security Notes

- Never commit API keys to version control
- The `~/.appstoreconnect/` directory should not be in any git repository
- API keys can be revoked at any time from App Store Connect
