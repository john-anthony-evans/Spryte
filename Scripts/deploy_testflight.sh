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
# - App must exist in App Store Connect (one-time setup)
#
# Usage:
#   ./Scripts/deploy_testflight.sh
#   ./Scripts/deploy_testflight.sh --dry-run

set -e

# ===========================================
# Configuration
# ===========================================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_NAME="Spryte"
SCHEME="Spryte"
XCODEPROJ="${PROJECT_ROOT}/${PROJECT_NAME}.xcodeproj"
EXPORT_OPTIONS="${PROJECT_ROOT}/ExportOptions.plist"

# App Store Connect details
APP_ID="6756588381"
BUNDLE_ID="com.doordash.spryte"
TEAM_ID="K2XB837E84"

# API credentials (can be overridden by env vars or arguments)
API_KEY_ID="${ASC_API_KEY_ID:-TA8277P6W3}"
API_ISSUER_ID="${ASC_API_ISSUER_ID:-69a6de7e-e168-47e3-e053-5b8c7c11a4d1}"

# Output directories
BUILD_DIR="${PROJECT_ROOT}/build"
ARCHIVE_PATH="${BUILD_DIR}/${PROJECT_NAME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export"

# ===========================================
# Colors and logging
# ===========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# ===========================================
# Parse arguments
# ===========================================
DRY_RUN=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
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
            echo "  --dry-run          Build and export but don't upload"
            echo "  --verbose, -v      Show full xcodebuild output"
            echo "  --key-id <ID>      Override API Key ID"
            echo "  --issuer-id <ID>   Override Issuer ID"
            echo "  --help             Show this help message"
            echo ""
            echo "Environment variables (optional, defaults are set):"
            echo "  ASC_API_KEY_ID     API Key ID"
            echo "  ASC_API_ISSUER_ID  Issuer ID"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# ===========================================
# Validate prerequisites
# ===========================================
if [[ "$DRY_RUN" == false ]]; then
    API_KEY_FILE="$HOME/.appstoreconnect/private_keys/AuthKey_${API_KEY_ID}.p8"
    if [[ ! -f "$API_KEY_FILE" ]]; then
        log_error "API key file not found: $API_KEY_FILE"
        log_error "Download from: https://appstoreconnect.apple.com/access/integrations/api"
        exit 1
    fi
    log_info "Using API key: $API_KEY_ID"
fi

if [[ ! -f "$EXPORT_OPTIONS" ]]; then
    log_error "ExportOptions.plist not found at: $EXPORT_OPTIONS"
    exit 1
fi

# ===========================================
# Increment build number
# ===========================================
mkdir -p "$BUILD_DIR"

log_step "Incrementing build number..."
PBXPROJ="${XCODEPROJ}/project.pbxproj"

CURRENT_BUILD=$(grep -m1 "CURRENT_PROJECT_VERSION = " "$PBXPROJ" | sed 's/.*= \([0-9]*\);/\1/')
if [[ -z "$CURRENT_BUILD" ]]; then
    CURRENT_BUILD=0
fi

NEW_BUILD=$((CURRENT_BUILD + 1))
log_info "Build number: $CURRENT_BUILD -> $NEW_BUILD"

sed -i '' "s/CURRENT_PROJECT_VERSION = $CURRENT_BUILD;/CURRENT_PROJECT_VERSION = $NEW_BUILD;/g" "$PBXPROJ"

MARKETING_VERSION=$(grep -m1 "MARKETING_VERSION = " "$PBXPROJ" | sed 's/.*= \([^;]*\);/\1/')
log_info "Version: $MARKETING_VERSION ($NEW_BUILD)"

# ===========================================
# Archive
# ===========================================
log_step "Cleaning previous build..."
rm -rf "$ARCHIVE_PATH"
rm -rf "$EXPORT_PATH"

log_step "Archiving ${PROJECT_NAME}... (this takes ~1 minute)"

if [[ "$VERBOSE" == true ]]; then
    xcodebuild archive \
        -project "$XCODEPROJ" \
        -scheme "$SCHEME" \
        -sdk iphoneos \
        -configuration Release \
        -archivePath "$ARCHIVE_PATH" \
        -destination 'generic/platform=iOS' \
        CODE_SIGN_STYLE=Automatic \
        DEVELOPMENT_TEAM=$TEAM_ID
else
    xcodebuild archive \
        -project "$XCODEPROJ" \
        -scheme "$SCHEME" \
        -sdk iphoneos \
        -configuration Release \
        -archivePath "$ARCHIVE_PATH" \
        -destination 'generic/platform=iOS' \
        CODE_SIGN_STYLE=Automatic \
        DEVELOPMENT_TEAM=$TEAM_ID \
        -quiet 2>&1 | grep -E "(error:|warning:|\*\*)" || true
fi

if [[ ! -d "$ARCHIVE_PATH" ]]; then
    log_error "Archive failed - no archive created"
    exit 1
fi
log_info "Archive created successfully"

# ===========================================
# Export IPA
# ===========================================
log_step "Exporting IPA..."

if [[ "$VERBOSE" == true ]]; then
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportOptionsPlist "$EXPORT_OPTIONS" \
        -exportPath "$EXPORT_PATH" \
        -allowProvisioningUpdates
else
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportOptionsPlist "$EXPORT_OPTIONS" \
        -exportPath "$EXPORT_PATH" \
        -allowProvisioningUpdates \
        -quiet 2>&1 | grep -E "(error:|warning:)" || true
fi

IPA_FILE=$(find "$EXPORT_PATH" -name "*.ipa" -type f | head -1)
if [[ -z "$IPA_FILE" ]]; then
    log_error "Export failed - no IPA file found"
    exit 1
fi

IPA_SIZE=$(du -h "$IPA_FILE" | cut -f1)
log_info "IPA created: $IPA_SIZE"

# ===========================================
# Upload to TestFlight
# ===========================================
if [[ "$DRY_RUN" == true ]]; then
    log_warn "Dry run - skipping upload"
    log_info "IPA ready at: $IPA_FILE"
else
    log_step "Uploading to TestFlight... (this takes ~30 seconds)"

    xcrun altool --upload-app \
        --type ios \
        --file "$IPA_FILE" \
        --apiKey "$API_KEY_ID" \
        --apiIssuer "$API_ISSUER_ID" 2>&1 | grep -v "^$"

    log_info "Upload complete!"
fi

# ===========================================
# Summary
# ===========================================
echo ""
echo -e "${CYAN}==========================================${NC}"
echo -e "${CYAN} Deployment Summary${NC}"
echo -e "${CYAN}==========================================${NC}"
echo "  App:       Spryte Icon Preview"
echo "  Bundle:    $BUNDLE_ID"
echo "  Version:   $MARKETING_VERSION ($NEW_BUILD)"
echo "  IPA Size:  $IPA_SIZE"
echo ""
if [[ "$DRY_RUN" == true ]]; then
    echo -e "  Status:    ${YELLOW}Built (dry run - not uploaded)${NC}"
else
    echo -e "  Status:    ${GREEN}Uploaded to TestFlight${NC}"
    echo ""
    echo "  Links:"
    echo "    App Store Connect: https://appstoreconnect.apple.com/apps/$APP_ID/testflight"
    echo "    TestFlight (web):  https://beta.itunes.apple.com/v1/app/$APP_ID"
    echo ""
    echo -e "  ${YELLOW}Note: Build takes 5-15 min to process before appearing in TestFlight${NC}"
fi
echo -e "${CYAN}==========================================${NC}"
