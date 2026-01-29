#!/usr/bin/env bash
set -e

# Determine the project root (directory containing this script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/.."
cd "$PROJECT_ROOT"


# Clean previous build artifacts
echo "Cleaning previous build artifacts..."
rm -rf flatpak-build flatpak-repo .flatpak-builder
rm -rf flatpak-source/*

# 1. Build the Tauri project (Rust binary + resources)
echo "Building Tauri project..."
export PATH="$PATH:$(pwd)/node_modules/.bin"
npm run tauri build -- --no-bundle --config '{"bundle":{"createUpdaterArtifacts":false},"plugins":{"updater":{"active":false}}}'

# 2. Prepare flatpak-source directory
# We rely entirely on the GNOME runtime for GTK, WebKit, and system libraries
echo "Preparing flatpak-source directory..."
mkdir -p flatpak-source

# Copy binary
cp src-tauri/target/release/Singularity flatpak-source/Singularity

# Copy bundled resources (locales, etc.)
# Tauri's resolveResource() expects these next to the binary at runtime
if [ -d src-tauri/target/release/locales ]; then
  echo "Copying locale files..."
  cp -r src-tauri/target/release/locales flatpak-source/locales
fi

# Copy icon
if [ -f src-tauri/icons/128x128.png ]; then
  cp src-tauri/icons/128x128.png flatpak-source/singularity.png
fi

# Copy metainfo.xml for Flatpak
cp flatpak/com.syzzle.singularity.metainfo.xml flatpak-source/singularity.metainfo.xml

# Copy screenshots for Flatpak metainfo
echo "Copying screenshots for Flatpak..."
mkdir -p flatpak-source/screenshots
cp screenshots/Screenshot*.png flatpak-source/screenshots/

# 3. Create singularity-wrapper script for Flatpak
# For Flatpak, let GTK auto-detect the backend (Wayland or X11)
# The GNOME runtime's WebKitGTK should handle Wayland correctly
# Set SINGULARITY_FLATPAK to signal to the Rust code not to force X11
cat > flatpak-source/singularity-wrapper << 'EOF'
#!/bin/bash
export SINGULARITY_FLATPAK=1
exec /app/bin/singularity "$@"
EOF
chmod +x flatpak-source/singularity-wrapper

# 4. Copy desktop file template for Flatpak
cp flatpak/singularity-mm.desktop.template flatpak-source/singularity.desktop


echo "Running flatpak-builder..."
flatpak-builder --repo=flatpak-repo --force-clean flatpak-build flatpak/com.syzzle.singularity.json
echo "Creating Flatpak bundle..."
flatpak build-bundle flatpak-repo SingularityMM.flatpak com.syzzle.singularity
echo "Flatpak build and bundle complete. Output: SingularityMM.flatpak"
