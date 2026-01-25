#!/usr/bin/env bash
set -e

# Clean previous build artifacts
echo "Cleaning previous build artifacts..."
rm -rf flatpak-build flatpak-repo .flatpak-builder
rm -rf steam-deck-package/lib/*
rm -rf steam-deck-package/bin/*
rm -rf flatpak-source/lib/*
rm -rf flatpak-source/bin/* 2>/dev/null || true

# 1. Build the Tauri project (Rust binary)
echo "Building Tauri project..."
npm run tauri build -- --no-bundle --config '{"bundle":{"createUpdaterArtifacts":false},"plugins":{"updater":{"active":false}}}'

# 2. Create packaging directories
echo "Creating packaging directories..."
mkdir -p steam-deck-package/bin steam-deck-package/lib

# 3. Copy the binary
echo "Copying Singularity binary..."
cp src-tauri/target/release/Singularity steam-deck-package/bin/

# 4. Analyze and copy dynamic library dependencies
echo "Analyzing and copying binary dependencies..."
ldd steam-deck-package/bin/Singularity | grep "=> /" | awk '{print $3}' | sort -u > all_deps.txt
while read -r lib; do
  if [[ -f "$lib" && "$lib" != "/lib64/ld-linux-x86-64.so.2" ]]; then
    libname=$(basename "$lib")
    # Exclude core system libraries and Flatpak runtime libraries
    if [[ ! "$libname" =~ ^(libc\.so\.|libdl\.so\.|libpthread\.so\.|libm\.so\.|librt\.so\.|libresolv\.so\.|libnss_.*\.so\.|libutil\.so\.|ld-linux.*|libgtk-3\.so\.|libgdk-3\.so\.|libgdk_pixbuf-2\.0\.so\.|libglib-2\.0\.so\.|libgobject-2\.0\.so\.|libpango-1\.0\.so\.|libpangocairo-1\.0\.so\.|libpangoft2-1\.0\.so\.|libatk-1\.0\.so\.|libatk-bridge-2\.0\.so\.|libcairo\.so\.|libcairo-gobject\.so\.|libgio-2\.0\.so\.|libmount\.so\.1$|libblkid\.so\.1$|libsystemd\.so\.|libatspi\.so\.|libjson-glib-1.0\.so\.|libgpg-error\.so\.|libgcrypt\.so\.|libwebkit2gtk.*|libjavascriptcoregtk.*|libc\.so.*).*$ ]]; then
      if [[ ! -f "steam-deck-package/lib/$libname" ]]; then
        echo "Copying $lib -> steam-deck-package/lib/$libname"
        cp "$lib" "steam-deck-package/lib/$libname" || echo "Failed to copy $lib"
      fi
    else
      echo "Excluding system/runtime library: $libname (will use Flatpak runtime version)"
    fi
  fi
done < all_deps.txt

# 5. Prepare flatpak-source directory
# Remove problematic libraries before Flatpak build
rm -f steam-deck-package/lib/libmount.so.1 steam-deck-package/lib/libblkid.so.1
rm -f flatpak-source/lib/libmount.so.1 flatpak-source/lib/libblkid.so.1
echo "Preparing flatpak-source directory..."
mkdir -p flatpak-source
cp com.syzzle.singularity.json flatpak-source/
cp steam-deck-package/bin/Singularity flatpak-source/
cp -r steam-deck-package/lib flatpak-source/
if [ -f src-tauri/icons/128x128.png ]; then
  cp src-tauri/icons/128x128.png flatpak-source/singularity.png
fi

# 6. Create singularity-wrapper script for Flatpak
cat > flatpak-source/singularity-wrapper << 'EOF'
#!/bin/bash
export LD_LIBRARY_PATH="/app/lib:$LD_LIBRARY_PATH"
export GDK_BACKEND=x11
export EGL_PLATFORM=x11
export ATK_ADAPTOR=dbus
export WEBKIT_EXEC_PATH="/app/libexec"
exec /app/bin/singularity "$@"
EOF
chmod +x flatpak-source/singularity-wrapper

# 7. Create singularity.desktop for Flatpak
cat > flatpak-source/singularity.desktop << 'EOF'
[Desktop Entry]
Name=Singularity Mod Manager
Exec=singularity-wrapper
Icon=com.syzzle.singularity
Type=Application
Categories=Utility;Game;
Comment=Manage your game modifications
Keywords=mods;modding;games;
EOF

echo "Done. You can now run flatpak-builder."
echo "Running flatpak-builder..."
flatpak-builder --repo=flatpak-repo --force-clean flatpak-build com.syzzle.singularity.json
echo "Creating Flatpak bundle..."
flatpak build-bundle flatpak-repo SingularityMM.flatpak com.syzzle.singularity
echo "Flatpak build and bundle complete. Output: SingularityMM.flatpak"
