---
description: Build and deploy Spryte to TestFlight
---

# Deploy to TestFlight

Build and upload Spryte to TestFlight for beta testing.

## Instructions

1. First, check if this is a dry run by looking for `--dry-run` in the user's command

2. Show the current version info:
   ```bash
   cd "/Users/john/Documents/Icon Test/Spryte" && grep -E "MARKETING_VERSION|CURRENT_PROJECT_VERSION" Spryte.xcodeproj/project.pbxproj | head -2
   ```

3. Run the deployment script:
   - For normal deployment: `./Scripts/deploy_testflight.sh`
   - For dry run: `./Scripts/deploy_testflight.sh --dry-run`

4. The script will:
   - Increment the build number automatically
   - Archive the app for Release
   - Export an IPA for App Store Connect
   - Upload to TestFlight (unless dry run)

5. Report the results to the user including:
   - New version and build number
   - Location of IPA file
   - Success/failure status

## Prerequisites

Before first use:
- App Store Connect API key must exist at `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8`
- Environment variables must be set: `ASC_API_KEY_ID`, `ASC_API_ISSUER_ID`
- See DEPLOYMENT.md for setup instructions

## Arguments

Pass any arguments after the command:
- `/deploy-testflight` - Full deployment
- `/deploy-testflight --dry-run` - Build only, don't upload
- `/deploy-testflight --key-id X --issuer-id Y` - Use specific credentials
