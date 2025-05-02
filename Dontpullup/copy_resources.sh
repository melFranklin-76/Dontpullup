#!/bin/bash
# Script to ensure resources are properly copied to the app bundle

# Get the target build dir from Xcode environment variable
APP_BUNDLE="$BUILT_PRODUCTS_DIR/$PRODUCT_NAME.app"
RESOURCES_DIR="$SRCROOT/dontpullup/Resources"

# Create destination directories if they don't exist
mkdir -p "$APP_BUNDLE/Resources"
mkdir -p "$APP_BUNDLE/Resources/MapStyles"

# Copy MapStyles directory
if [ -d "$RESOURCES_DIR/MapStyles" ]; then
    echo "Copying MapStyles files to app bundle..."
    cp -R "$RESOURCES_DIR/MapStyles/"* "$APP_BUNDLE/Resources/MapStyles/"
    echo "MapStyles files copied successfully."
else
    echo "Warning: MapStyles directory not found at $RESOURCES_DIR/MapStyles"
fi

# Copy default.csv
if [ -f "$RESOURCES_DIR/default.csv" ]; then
    echo "Copying default.csv to app bundle..."
    cp "$RESOURCES_DIR/default.csv" "$APP_BUNDLE/Resources/"
    echo "default.csv copied successfully."
else
    echo "Warning: default.csv not found at $RESOURCES_DIR/default.csv"
fi

# Set file permissions
chmod -R 755 "$APP_BUNDLE/Resources"

echo "Resource copying completed." 