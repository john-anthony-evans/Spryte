---
description: Deploy Spryte to TestFlight (build, export, upload)
---

# Deploy to TestFlight

Deploy the current code to TestFlight for beta testing.

## What This Does

1. Increments the build number automatically
2. Archives the app for Release (~1 min)
3. Exports IPA for App Store distribution
4. Uploads to TestFlight (~30 sec)
5. Shows links to App Store Connect

## Instructions

Run the deployment script:

```bash
cd "/Users/john/Documents/Icon Test/Spryte" && ./Scripts/deploy_testflight.sh
```

For a dry run (build only, no upload):
```bash
cd "/Users/john/Documents/Icon Test/Spryte" && ./Scripts/deploy_testflight.sh --dry-run
```

## After Deployment

- Build takes **5-15 minutes** to process before appearing in TestFlight
- Internal testers (DoorDash Design group) automatically get access
- App Store Connect: https://appstoreconnect.apple.com/apps/6756588381/testflight

## Troubleshooting

If the build doesn't appear in TestFlight:
1. Wait 5-15 minutes for processing
2. Force quit and reopen TestFlight app
3. Check App Store Connect for build status

For verbose output to debug issues:
```bash
./Scripts/deploy_testflight.sh --verbose
```
