#!/usr/bin/bash
# --- 4. MOTD TEMPLATE ---
cat > /usr/share/ublue-os/motd/template.md << 'EOF'
# 🌍 Welcome to Geonix
**GIS and Remote Sensing out of the box.**

🚀 `${MOTD_IMAGE_NAME}:${MOTD_IMAGE_TAG}`

| Command | Description |
|---------|-------------|
| `gj --list` | Show all available commands |
| `gj status` | Show installed GIS recipes |
| `gj install-bundle-rs` | Install Remote Sensing stack |
| `gj install-bundle-lidar` | Install LiDAR stack |
| `gj install-qgis-plugins` | Install QGIS plugins |
| `qgis` | Launch QGIS Desktop |

${MOTD_TIP}

- [Geonix Repository](https://github.com/a2rk313/geonix)
- [Report an Issue](https://github.com/a2rk313/geonix/issues)
EOF
echo "MOTD template written"

# --- 5. PLYMOUTH ---
PLYMOUTH_THEME="/usr/share/plymouth/themes/spinner"
if [[ -d "$PLYMOUTH_THEME" ]]; then
    cp /build-assets/logo/logo_small_128.png "${PLYMOUTH_THEME}/watermark.png"
    cp /build-assets/logo/logo_small_128.png "${PLYMOUTH_THEME}/bgrt-fallback.png"
    cp /build-assets/logo/logo_small_128.png "${PLYMOUTH_THEME}/silverblue-watermark.png"
    cp /build-assets/logo/logo_small_128.png "/usr/share/icons/hicolor/scalable/apps/geonix-logo.png"
    echo "Plymouth branding applied"
else
    echo "WARNING: Plymouth spinner theme not found, skipping"
fi

# --- 7. DESKTOP ENVIRONMENT BRANDING ENGINE ---
echo "Initializing Multi-Target DE Detection..."

# Normalize the target environment variables to lowercase for safe matching
DE_TARGET="unknown"

if [[ "${IMAGE_NAME,,}" == *"gnome"* || "${BASE_VARIANT,,}" == "bluefin" || "${BASE_VARIANT,,}" == "silverblue" ]]; then
    DE_TARGET="gnome"
elif [[ "${IMAGE_NAME,,}" == *"plasma"* || "${BASE_VARIANT,,}" == "kinoite" || "${BASE_VARIANT,,}" == "bazzite" ]]; then
    DE_TARGET="kde"
fi

echo "Detected Desktop Environment Target: [ $DE_TARGET ]"

# ---------------------------------------------------------
# BRANCH A: GNOME / BLUEFIN COMPILATION
# ---------------------------------------------------------
if [[ "$DE_TARGET" == "gnome" ]]; then
    echo "Executing GNOME Schema Overrides..."

    EXT_DIR="/usr/share/gnome-shell/extensions/logomenu@aryan_k"
    if [ -d "$EXT_DIR" ]; then
        cp "$EXT_DIR/schemas/org.gnome.shell.extensions.logo-menu.gschema.xml" \
            /usr/share/glib-2.0/schemas/ || true
    fi

    # Compile the dconf registry override
    cat > /usr/share/glib-2.0/schemas/99-geonix-logo.gschema.override << 'EOF'
[org.gnome.shell.extensions.logo-menu]
use-custom-icon=true
menu-button-icon-image=2
custom-icon-path='/usr/share/icons/hicolor/scalable/apps/geonix-logo.png'
menu-button-terminal='ptyxis'
menu-button-software-center='gnome-software'
EOF

    glib-compile-schemas /usr/share/glib-2.0/schemas/
    echo "GNOME configuration locked."

# ---------------------------------------------------------
# BRANCH B: KDE PLASMA COMPILATION
# ---------------------------------------------------------
elif [[ "$DE_TARGET" == "kde" ]]; then
    echo "Executing KDE Plasma Plaintext Overrides..."

    # --- KDE Kickoff (Application Launcher) Modification ---
    # KDE stores default plasmoid settings in XML config files.
    # We use sed to rewrite the default icon string in the immutable tree.
    KICKOFF_XML="/usr/share/plasma/plasmoids/org.kde.plasma.kickoff/contents/config/main.xml"

    if [[ -f "$KICKOFF_XML" ]]; then
        # Swap the default "start-here-kde" icon with our newly registered XDG asset
        sed -i 's|<default>start-here-kde</default>|<default>geonix-logo</default>|g' "$KICKOFF_XML"
        echo "KDE Kickoff icon overridden."
    else
        echo "WARNING: KDE Kickoff main.xml not found."
    fi

else
    echo "WARNING: Unknown DE target. Skipping graphical branding."
fi
