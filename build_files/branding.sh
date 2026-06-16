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
    cp /ctx/logo/logo_small_128.png "/usr/share/icons/hicolor/scalable/apps/geonix-logo.png"
    echo "Plymouth branding applied"
else
    echo "WARNING: Plymouth spinner theme not found, skipping"
fi

SCHEMA_PATH="/usr/share/gnome-shell/extensions/logomenu@aryan_k/schemas"
# Force GNOME to compile the extension's XML schemas into the required binary format
glib-compile-schemas $SCHEMA_PATH
gsettings --schemadir $SCHEMA_PATH set org.gnome.shell.extensions.logo-menu use-custom-icon true
gsettings --schemadir $SCHEMA_PATH set org.gnome.shell.extensions.logo-menu menu-button-icon-image 2
gsettings --schemadir $SCHEMA_PATH set org.gnome.shell.extensions.logo-menu custom-icon-path '/usr/share/icons/hicolor/scalable/apps/geonix-logo.png'

# --- KDE Kickoff (Application Launcher) Modification ---
# KDE stores default plasmoid settings in XML config files.
# We use sed to rewrite the default icon string in the immutable tree.
KICKOFF_XML="/usr/share/plasma/plasmoids/org.kde.plasma.kickoff/contents/config/main.xml"
# Swap the default "start-here-kde" icon with our newly registered XDG asset
sed -i 's|<default>start-here-kde</default>|<default>geonix-logo</default>|g' "$KICKOFF_XML"
echo "KDE Kickoff icon overridden."

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
