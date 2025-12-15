#!/bin/bash

# deploy_testflight.sh - Build and deploy Spryte to TestFlight
#
# This script:
# 1. Increments the build number
# 2. Archives the app
# 3. Exports IPA for App Store
# 4. Uploads to TestFlight via App Store Connect API
#
# Prerequisites:
# - App Store Connect API key at ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8
# - Environment variables: ASC_API_KEY_ID, ASC_API_ISSUER_ID
# - Or pass as arguments: --key-id <KEY_ID> --issuer-id <ISSUER_ID>
#
# Usage:
#   ./Scripts/deploy_testflight.sh
#   ./Scripts/deploy_testflight.sh --key-id ABC123 --issuer-id 12345678-1234-...
#   ./Scripts/deploy_testflight.sh --dry-run

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_NAME="Spryte"
SCHEME="Spryte"
XCODEPROJ="${PROJECT_ROOT}/${PROJECT_NAME}.xcodeproj"
EXPORT_OPTIONS="${PROJECT_ROOT}/ExportOptions.plist"

# Output directories
BUILD_DIR="${PROJECT_ROOT}/build"
ARCHIVE_PATH="${BUILD_DIR}/${PROJECT_NAME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Parse arguments
DRY_RUN=false
API_KEY_ID="${ASC_API_KEY_ID:-}"
API_ISSUER_ID="${ASC_API_ISSUER_ID:-}"

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --key-id)
            API_KEY_ID="$2"
            shift 2
            ;;
        --issuer-id)
            API_ISSUER_ID="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --key-id <ID>      App Store Connect API Key ID"
            echo "  --issuer-id <ID>   App Store Connect Issuer ID"
            echo "  --dry-run          Build and export but don't upload"
            echo "  --help             Show this help message"
            echo ""
            echo "Environment variables:"
            echo "  ASC_API_KEY_ID     API Key ID (alternative to --key-id)"
            echo "  ASC_API_ISSUER_ID  Issuer ID (alternative to --issuer-id)"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate API credentials (unless dry run)
if [[ "$DRY_RUN" == false ]]; then
    if [[ -z "$API_KEY_ID" || -z "$API_ISSUER_ID" ]]; then
        log_error "App Store Connect API credentials required"
        log_error "Set ASC_API_KEY_ID and ASC_API_ISSUER_ID environment variables"
        log_error "Or use --key-id and --issuer-id arguments"
        exit 1
    fi

    # Check for API key file
    API_KEY_FILE="$HOME/.appstoreconnect/private_keys/AuthKey_${API_KEY_ID}.p8"
    if [[ ! -f "$API_KEY_FILE" ]]; then
        log_error "API key file not found: $API_KEY_FILE"
        log_error "Download your API key from App Store Connect and place it at:"
        log_error "  ~/.appstoreconnect/private_keys/AuthKey_${API_KEY_ID}.p8"
        exit 1
    fi
    log_info "Found API key file: $API_KEY_FILE"
fi

# Check for ExportOptions.plist
if [[ ! -f "$EXPORT_OPTIONS" ]]; then
    log_error "ExportOptions.plist not found at: $EXPORT_OPTIONS"
    exit 1
fi

# Create build directory
mkdir -p "$BUILD_DIR"

# Get current build number and increment
log_step "Incrementing build number..."
PBXPROJ="${XCODEPROJ}/project.pbxproj"

# Extract current build number (CURRENT_PROJECT_VERSION)
CURRENT_BUILD=$(grep -m1 "CURRENT_PROJECT_VERSION = " "$PBXPROJ" | sed 's/.*= \([0-9]*\);/\1/')
if [[ -z "$CURRENT_BUILD" ]]; then
    CURRENT_BUILD=0
fi

NEW_BUILD=$((CURRENT_BUILD + 1))
log_info "Build number: $CURRENT_BUILD -> $NEW_BUILD"

# Update build number in both Debug and Release configurations
sed -i '' "s/CURRENT_PROJECT_VERSION = $CURRENT_BUILD;/CURRENT_PROJECT_VERSION = $NEW_BUILD;/g" "$PBXPROJ"

# Get marketing version for logging
MARKETING_VERSION=$(grep -m1 "MARKETING_VERSION = " "$PBXPROJ" | sed 's/.*= \([^;]*\);/\1/')
log_info "Version: $MARKETING_VERSION ($NEW_BUILD)"

# Clean build directory
log_step "Cleaning previous build..."
rm -rf "$ARCHIVE_PATH"
rm -rf "$EXPORT_PATH"

# Archive the app
log_step "Archiving ${PROJECT_NAME}..."
xcodebuild archive \
    -project "$XCODEPROJ" \
    -scheme "$SCHEME" \
    -sdk iphoneos \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -destination 'generic/platform=iOS' \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM=K2XB837E84 \
    | xcpretty || true

if [[ ! -d "$ARCHIVE_PATH" ]]; then
    log_error "Archive failed - no archive created"
    exit 1
fi
log_info "Archive created: $ARCHIVE_PATH"

# Export IPA
log_step "Exporting IPA..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -exportPath "$EXPORT_PATH" \
    -allowProvisioningUpdates \
    | xcpretty || true

# Find the exported IPA
IPA_FILE=$(find "$EXPORT_PATH" -name "*.ipa" -type f | head -1)
if [[ -z "$IPA_FILE" ]]; then
    log_error "Export failed - no IPA file found"
    exit 1
fi
log_info "IPA created: $IPA_FILE"

# Upload to TestFlight (unless dry run)
if [[ "$DRY_RUN" == true ]]; then
    log_warn "Dry run - skipping upload to TestFlight"
    log_info "IPA ready at: $IPA_FILE"
else
    log_step "Uploading to TestFlight..."

    # Use xcrun altool for upload
    xcrun altool --upload-app \
        --type ios \
        --file "$IPA_FILE" \
        --apiKey "$API_KEY_ID" \
        --apiIssuer "$API_ISSUER_ID"

    log_info "Upload complete!"
fi

# Summary
echo ""
echo "=========================================="
log_info "Deployment Summary"
echo "=========================================="
echo "  App:      ${PROJECT_NAME}"
echo "  Version:  ${MARKETING_VERSION} (${NEW_BUILD})"
echo "  IPA:      ${IPA_FILE}"
if [[ "$DRY_RUN" == true ]]; then
    echo "  Status:   Built (dry run - not uploaded)"
else
    echo "  Status:   Uploaded to TestFlight"
fi
echo "=========================================="
