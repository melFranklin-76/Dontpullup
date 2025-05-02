#!/bin/bash
# Script to ensure proper debug symbols are generated

# Output marker files to help Xcode dependency analysis
MARKER_DIR="${BUILT_PRODUCTS_DIR}/.markers"
mkdir -p "${MARKER_DIR}"
DSYM_MARKER="${MARKER_DIR}/fix_dsym_executed"
RESOURCE_MARKER="${MARKER_DIR}/resources_verified"

# Check if running in debug configuration
if [ "$CONFIGURATION" = "Debug" ]; then
    echo "Ensuring debug symbols are properly generated..."
    
    # Force debug symbol generation
    if [ -d "$DWARF_DSYM_FOLDER_PATH/$DWARF_DSYM_FILE_NAME" ]; then
        # Clean the dSYM to regenerate it
        rm -rf "$DWARF_DSYM_FOLDER_PATH/$DWARF_DSYM_FILE_NAME"
    fi
    
    # Set environment variables to ensure proper dSYM generation
    export STRIP_INSTALLED_PRODUCT=NO
    export STRIP_STYLE=debugging
    export DEBUG_INFORMATION_FORMAT=dwarf-with-dsym
    export DEPLOYMENT_POSTPROCESSING=NO
    
    echo "Debug symbol generation configured."
    
    # Create marker file for debug symbol generation
    touch "${DSYM_MARKER}"
fi

# Ensure resources are properly copied
echo "Checking resource files..."

# Check if default.csv exists in the final app bundle
APP_BUNDLE="$BUILT_PRODUCTS_DIR/$PRODUCT_NAME.app"
APP_RESOURCES="${APP_BUNDLE}/Resources"
mkdir -p "${APP_RESOURCES}"

# If default.csv doesn't exist in app bundle, create it
DEFAULT_CSV="${APP_RESOURCES}/default.csv"
if [ ! -f "${DEFAULT_CSV}" ]; then
    echo "default.csv not found in app bundle, creating..."
    
    # Create a simple default.csv directly
    echo "type,color,icon
911,#FF0000,emergency_icon
Physical,#FF4500,physical_icon
Verbal,#FFA500,verbal_icon" > "${DEFAULT_CSV}"
    
    # Set proper permissions
    chmod 644 "${DEFAULT_CSV}"
    echo "Created default.csv in app bundle"
fi

# Create marker file for resource verification
touch "${RESOURCE_MARKER}"

echo "Resource check complete." 