#!/bin/zsh

# import_icons.sh - Import Icon Composer icons and generate preview PNGs
# This script is designed to run as an Xcode Build Phase

set -e

# Configuration
SRCROOT="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
ICONS_TO_IMPORT="${SRCROOT}/Icons to Import"
ICON_SOURCE="${SRCROOT}/Spryte/Icon Source"
PROJECT_ROOT="${SRCROOT}"
MANIFEST_FILE="${SRCROOT}/Spryte/icons_manifest.json"
ICTOOL="/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"

# IMPORTANT: Primary app icon - NEVER delete this file
PRIMARY_ICON_NAME="Default"

# Renditions to export
RENDITIONS=("Default" "Dark" "ClearLight" "ClearDark" "TintedLight" "TintedDark")

# Hash file for change detection
HASH_FILE="${DERIVED_FILE_DIR:-/tmp}/icons_import_hash"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo "${RED}[ERROR]${NC} $1"
}

# Check if ictool exists
if [[ ! -x "$ICTOOL" ]]; then
    log_error "ictool not found at $ICTOOL"
    log_error "Make sure Xcode 26+ is installed"
    exit 1
fi

# Check if source folder exists
if [[ ! -d "$ICONS_TO_IMPORT" ]]; then
    log_warn "Icons to Import folder not found at $ICONS_TO_IMPORT"
    log_warn "Skipping icon import"
    exit 0
fi

# Change detection
if [[ -n "$DERIVED_FILE_DIR" ]]; then
    CURRENT_HASH=$(find "$ICONS_TO_IMPORT" -type f \( -name "*.icon" -o -name "icon.json" \) -exec md5 -q {} \; 2>/dev/null | md5 -q)

    if [[ -f "$HASH_FILE" ]] && [[ "$(cat "$HASH_FILE" 2>/dev/null)" = "$CURRENT_HASH" ]]; then
        log_info "No icon changes detected, skipping import"
        exit 0
    fi
fi

log_info "Starting icon import from: $ICONS_TO_IMPORT"

# Create output directories
mkdir -p "$ICON_SOURCE"

# Use associative arrays (zsh supports these)
typeset -A SECTIONS
SECTION_ORDER=()

# Find all .icon files
find "$ICONS_TO_IMPORT" -name "*.icon" -type d | while read -r ICON_PATH; do
    # Get relative path from ICONS_TO_IMPORT
    REL_PATH="${ICON_PATH#$ICONS_TO_IMPORT/}"

    # Extract icon name (filename without .icon)
    ICON_FILE=$(basename "$ICON_PATH")
    ICON_NAME="${ICON_FILE%.icon}"

    # Sanitize icon name: replace spaces with hyphens
    ICON_NAME_SAFE=$(echo "$ICON_NAME" | tr ' ' '-')

    # Extract section from directory path
    ICON_DIR=$(dirname "$REL_PATH")
    if [[ "$ICON_DIR" = "." ]]; then
        SECTION="Uncategorized"
    else
        SECTION="$ICON_DIR"
    fi

    # Make unique: append last section component if icon would be a duplicate
    # e.g., Dasher/Inverted/Dasher 01.icon -> Dasher-01-Inverted
    #       Dasher/Default/Dasher 01.icon -> Dasher-01-Default
    if [[ "$SECTION" != "Uncategorized" ]]; then
        SECTION_SUFFIX=$(basename "$ICON_DIR" | tr ' ' '-')
        # Check if another icon with same base name exists in a different section
        DUPLICATE_COUNT=$(find "$ICONS_TO_IMPORT" -name "$ICON_FILE" -type d | wc -l | tr -d ' ')
        if [[ "$DUPLICATE_COUNT" -gt 1 ]]; then
            ICON_NAME_SAFE="${ICON_NAME_SAFE}-${SECTION_SUFFIX}"
        fi
    fi

    log_info "Processing: $ICON_NAME -> $ICON_NAME_SAFE (Section: $SECTION)"

    # Create export directory (using sanitized name)
    EXPORT_DIR="${ICON_SOURCE}/${ICON_NAME_SAFE}-Exports"
    mkdir -p "$EXPORT_DIR"

    # Export each rendition
    for RENDITION in "${RENDITIONS[@]}"; do
        OUTPUT_FILE="${EXPORT_DIR}/${ICON_NAME_SAFE}-iOS-${RENDITION}-1024x1024@1x.png"

        log_info "  Exporting $RENDITION..."

        if ! "$ICTOOL" "$ICON_PATH" \
            --export-image \
            --output-file "$OUTPUT_FILE" \
            --platform iOS \
            --rendition "$RENDITION" \
            --width 1024 \
            --height 1024 \
            --scale 1 2>/dev/null; then
            log_warn "  Failed to export $RENDITION for $ICON_NAME_SAFE"
        fi
    done

    # Copy .icon file to project root with sanitized name
    DEST_ICON="${PROJECT_ROOT}/${ICON_NAME_SAFE}.icon"
    if [[ "$ICON_PATH" != "$DEST_ICON" ]]; then
        log_info "  Copying .icon to project root as ${ICON_NAME_SAFE}.icon..."
        cp -R "$ICON_PATH" "$DEST_ICON"
    fi

    # Write to temp file for manifest generation (using sanitized name)
    echo "${SECTION}|${ICON_NAME_SAFE}" >> "/tmp/icons_manifest_temp.txt"
done

# Generate manifest JSON
log_info "Generating manifest file..."

# Build manifest from temp file
if [[ -f "/tmp/icons_manifest_temp.txt" ]]; then
    # Get unique sections in order (handle spaces properly)
    SECTION_LIST=()
    while IFS= read -r section; do
        SECTION_LIST+=("$section")
    done < <(cut -d'|' -f1 "/tmp/icons_manifest_temp.txt" | awk '!seen[$0]++')

    # Start JSON
    echo '{' > "$MANIFEST_FILE"
    echo '  "sections": [' >> "$MANIFEST_FILE"

    FIRST_SECTION=true
    for SECTION in "${SECTION_LIST[@]}"; do
        # Get icons for this section (escape special chars in section name for grep)
        ESCAPED_SECTION=$(printf '%s' "$SECTION" | sed 's/[[\.*^$()+?{|]/\\&/g')
        ICONS=$(grep "^${ESCAPED_SECTION}|" "/tmp/icons_manifest_temp.txt" | cut -d'|' -f2 | sed 's/.*/"&"/' | tr '\n' ',' | sed 's/,$//')

        if [[ "$FIRST_SECTION" = true ]]; then
            FIRST_SECTION=false
        else
            echo ',' >> "$MANIFEST_FILE"
        fi

        cat >> "$MANIFEST_FILE" << EOF
    {
      "name": "${SECTION}",
      "icons": [${ICONS}]
    }
EOF
    done

    echo '' >> "$MANIFEST_FILE"
    echo '  ]' >> "$MANIFEST_FILE"
    echo '}' >> "$MANIFEST_FILE"

    # Cleanup temp file
    rm -f "/tmp/icons_manifest_temp.txt"

    log_info "Manifest written to: $MANIFEST_FILE"
else
    log_warn "No icons found to process"
fi

# Save hash for change detection
if [[ -n "$DERIVED_FILE_DIR" ]]; then
    mkdir -p "$(dirname "$HASH_FILE")"
    echo "$CURRENT_HASH" > "$HASH_FILE"
fi

# ============================================
# Add new .icon files to Xcode project
# ============================================
PBXPROJ="${SRCROOT}/Spryte.xcodeproj/project.pbxproj"

if [[ -f "$PBXPROJ" ]]; then
    log_info "Checking for new .icon files to add to Xcode project..."

    # Find all .icon files at project root
    for ICON_FILE in "${PROJECT_ROOT}"/*.icon; do
        [[ -d "$ICON_FILE" ]] || continue

        ICON_BASENAME=$(basename "$ICON_FILE")

        # Check if already in project
        if grep -q "path = \"*${ICON_BASENAME}\"*;" "$PBXPROJ" 2>/dev/null; then
            log_info "  $ICON_BASENAME already in project"
            continue
        fi

        log_info "  Adding $ICON_BASENAME to Xcode project..."

        # Generate UUIDs (24 hex chars, uppercase)
        FILE_REF_UUID=$(uuidgen | tr -d '-' | cut -c1-24 | tr '[:lower:]' '[:upper:]')
        BUILD_FILE_UUID=$(uuidgen | tr -d '-' | cut -c1-24 | tr '[:lower:]' '[:upper:]')

        # Escape icon name for sed
        ESCAPED_NAME=$(printf '%s' "$ICON_BASENAME" | sed 's/[&/\]/\\&/g')

        # Add PBXFileReference entry (after existing PBXFileReference section start)
        sed -i '' "/\\/\\* Begin PBXFileReference section \\*\\//a\\
\\		${FILE_REF_UUID} /* ${ESCAPED_NAME} */ = {isa = PBXFileReference; lastKnownFileType = folder.iconcomposer.icon; path = \"${ESCAPED_NAME}\"; sourceTree = \"<group>\"; };
" "$PBXPROJ"

        # Add PBXBuildFile entry (after existing PBXBuildFile section start)
        sed -i '' "/\\/\\* Begin PBXBuildFile section \\*\\//a\\
\\		${BUILD_FILE_UUID} /* ${ESCAPED_NAME} in Resources */ = {isa = PBXBuildFile; fileRef = ${FILE_REF_UUID} /* ${ESCAPED_NAME} */; };
" "$PBXPROJ"

        # Add to main PBXGroup children (find the main group and add after first child)
        # The main group is the one containing Instructions.md
        sed -i '' "/52D2EF532EEDC1D5003D4E85.*= {/,/children = (/{
            /children = (/a\\
\\				${FILE_REF_UUID} /* ${ESCAPED_NAME} */,
        }" "$PBXPROJ"

        # Add to PBXResourcesBuildPhase files
        sed -i '' "/\\/\\* Begin PBXResourcesBuildPhase section \\*\\//,/\\/\\* End PBXResourcesBuildPhase section \\*\\//{
            /files = (/a\\
\\				${BUILD_FILE_UUID} /* ${ESCAPED_NAME} in Resources */,
        }" "$PBXPROJ"

        log_info "  Added $ICON_BASENAME to project"
    done
else
    log_warn "project.pbxproj not found, skipping auto-add"
fi

log_info "Icon import complete!"
