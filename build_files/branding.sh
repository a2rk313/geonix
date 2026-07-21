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
    cp /ctx/logo/logo_small_128.png "${PLYMOUTH_THEME}/watermark.png"
    cp /ctx/logo/logo_small_128.png "${PLYMOUTH_THEME}/bgrt-fallback.png"
    cp /ctx/logo/logo_small_128.png "${PLYMOUTH_THEME}/silverblue-watermark.png"
    cp /ctx/logo/logo_small_128.png "${PLYMOUTH_THEME}/silverblue-logo.png"
    cp /ctx/logo/logo_small_128.png "/usr/share/icons/hicolor/scalable/apps/geonix-logo.png"
    echo "Plymouth branding applied"
else
    echo "WARNING: Plymouth spinner theme not found, skipping"
fi

# --- GNOME Logomenu extension override (Bluefin only) ---
if [[ "${BASE_VARIANT:-}" == "bluefin" ]]; then
    cat > /usr/share/glib-2.0/schemas/99-geonix-branding.gschema.override << 'EOF'
[org.gnome.shell.extensions.logo-menu]
use-custom-icon=true
menu-button-icon-image=2
custom-icon-path='/usr/share/icons/hicolor/256x256/apps/geonix-logo.png'
menu-button-terminal='ptyxis'
menu-button-software-center='gnome-software'
EOF
    glib-compile-schemas /usr/share/glib-2.0/schemas/ 2>/dev/null || true
    echo "GNOME branding applied"
fi

# --- KDE Kickoff icon override (Aurora only) ---
if [[ "${BASE_VARIANT:-}" == "aurora" ]]; then
    KICKOFF_XML="/usr/share/plasma6/plasmoids/org.kde.plasma.kickoff/contents/config/main.xml"
    if [[ -f "$KICKOFF_XML" ]]; then
        sed -i 's|<default>start-here-kde</default>|<default>geonix-logo</default>|g' "$KICKOFF_XML"
        echo "KDE Kickoff icon overridden"
    else
        echo "WARNING: KDE Kickoff XML not found, skipping"
    fi
fi

# --- GDM / FEDORA LOGO REPLACEMENTS ---
PIXMAPS="/usr/share/pixmaps"
LOGO_128="/ctx/logo/logo_small_128.png"
LOGO_256="/ctx/logo/logo_small_256.png"

cp "$LOGO_128" "${PIXMAPS}/fedora-gdm-logo.png"
cp "$LOGO_128" "${PIXMAPS}/fedora-logo.png"
cp "$LOGO_128" "${PIXMAPS}/fedora-logo-icon.png"
cp "$LOGO_128" "${PIXMAPS}/fedora-logo-small.png"
cp "$LOGO_256" "${PIXMAPS}/fedora-logo-sprite.png"
cp "$LOGO_128" "${PIXMAPS}/fedora_logo_med.png"
cp "$LOGO_128" "${PIXMAPS}/fedora_whitelogo_med.png"
