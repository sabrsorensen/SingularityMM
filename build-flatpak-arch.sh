#!/bin/bash

# Exit on error
set -e

# Update system and install dependencies
echo "Updating system and installing dependencies..."
sudo pacman -Syu --noconfirm
sudo pacman -S --noconfirm \
    flatpak \
    flatpak-builder \
    base-devel \
    git \
    curl \
    wget \
    patchelf \
    desktop-file-utils \
    fuse2 \
    glib2 \
    gtk3 \
    webkit2gtk \
    pango \
    cairo \
    librsvg \
    at-spi2-core \
    libx11 \
    libxkbcommon \
    libxrandr \
    libxcomposite \
    libxdamage \
    libxrender \
    libxext \
    libxtst \
    libxi \
    libxfixes \
    libxinerama \
    libxrandr \
    libxcursor \
    libxss \
    libxshmfence \
    libxkbfile \
    libxkbcommon-x11 \
    libxft \
    libxmu \
    libxpm \
    libxres \
    libxt \
    libxv \
    libxvmc \
    libxxf86vm \
    libsm \
    libice

# Add Flathub repository
echo "Adding Flathub repository..."
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install Flatpak runtime and SDK
echo "Installing Flatpak runtime and SDK..."
flatpak install -y flathub org.freedesktop.Platform//23.08 org.freedesktop.Sdk//23.08

# Build Flatpak package
echo "Building Flatpak package..."
mkdir -p flatpak-build flatpak-repo
flatpak-builder --user --install-deps-from=flathub --disable-rofiles-fuse --force-clean --repo=flatpak-repo flatpak-build com.syzzle.singularity.json

# Export Flatpak bundle
echo "Exporting Flatpak bundle..."
flatpak build-bundle flatpak-repo singularity-mm-steam-deck.flatpak com.syzzle.singularity

# Output success message
echo "Flatpak build completed successfully. The bundle is available as singularity-mm-steam-deck.flatpak."