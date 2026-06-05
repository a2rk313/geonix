#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

dnf5 -y copr enable megger/saga

# this installs a package from fedora repos
dnf5 install -y gdal python3-gdal geos proj proj-data libgeotiff libspatialite spatialite-tools spatialindex postgis postgresql qgis python3-qgis qgis-grass grass saga \
python3-shapely python3-fiona python3-pandas python3-numpy fuse fuse-libs \
 && dnf5 clean all

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

dnf5 -y copr disable megger/saga

# No age attestation or verification allowed here
systemctl mask systemd-homed

# Enabled systemd services
systemctl enable podman.socket

# Fix for ID= parameter for osbuild
if [ -f /usr/lib/os-release.d/os-release-fedora ]; then
    sed -i 's/^ID=.*$/ID=fedora/' /usr/lib/os-release.d/os-release-fedora
fi

echo 'VARIANT_ID="geonix"' >> /usr/lib/os-release
echo 'NAME="Geonix"' >> /usr/lib/os-release

# --- 4. PLYMOUTH BOOT SCREEN BRANDING ---
echo "--> Applying custom Geonix boot logos..."

# Injecting the pre-scaled 256x256 transparent logo directly into the bootloader
cp /build-assets/logo/logo_small_256.png /usr/share/plymouth/themes/spinner/watermark.png
cp /build-assets/logo/logo_small_256.png /usr/share/plymouth/themes/spinner/bgrt-fallback.png


# --- 5. DESKTOP ENVIRONMENT BRANDING (GNOME & KDE) ---
echo "--> Applying DE panel logos..."

mkdir -p /usr/share/icons/hicolor/scalable/apps/
# Destination Mapping: We rename the file to 'geonix-logo.png' upon injection
# so the GNOME schema override below does not need to be modified.
cp /build-assets/logo/logo_small_256.png /usr/share/icons/hicolor/scalable/apps/geonix-logo.png

echo "--> Configuring GNOME Logo Menu..."
cat <<EOF > /usr/share/glib-2.0/schemas/99-geonix-logo.gschema.override
[org.gnome.shell.extensions.Logo-menu]
menu-button-icon-image=2
custom-icon-path='/usr/share/icons/hicolor/scalable/apps/geonix-logo.png'
EOF
glib-compile-schemas /usr/share/glib-2.0/schemas/

echo "--> Configuring KDE Plasma Kickoff icon..."
mkdir -p /usr/share/icons/hicolor/scalable/places/

# Overwriting the default KDE Kickoff 'start-here' distribution icons
cp /build-assets/logo/logo_small_256.png /usr/share/icons/hicolor/scalable/places/start-here.png
cp /build-assets/logo/logo_small_256.png /usr/share/icons/hicolor/scalable/places/start-here-kde.png

# Rebuilding the icon cache index so the Desktop Environments immediately recognize the new binaries
gtk-update-icon-cache -f -t /usr/share/icons/hicolor || true


# --- 6. CLEANUP ---
# Destroy the staging directory to prevent container bloat
rm -rf /build-assets


# --- 7. NATIVE TERMINAL MOTD BRANDING ---
echo "--> Forging Image-Aware JSON Database..."

# 1. Secure Environment Variables with Generic Fallbacks
FINAL_REGISTRY=${IMAGE_REGISTRY:-"ghcr.io/a2rk313"}
FINAL_IMAGE_NAME=${IMAGE_NAME:-"geonix-plasma"}
FINAL_TAG=${DEFAULT_TAG:-"latest"}

# Extract vendor dynamically (e.g., ghcr.io/a2rk313 -> a2rk313)
VENDOR=${FINAL_REGISTRY##*/}

# Defensive Flavor Extraction: Checks if a hyphen exists.
# If "geonix-plasma", flavor becomes "plasma". If just "geonix", flavor becomes "main".
if [[ "$FINAL_IMAGE_NAME" == *"-"* ]]; then
    FLAVOR=${FINAL_IMAGE_NAME#*-}
else
    FLAVOR="main"
fi

# Extract the exact OS version from the system itself
source /usr/lib/os-release
OS_VERSION=$VERSION_ID

# 2. Surgical JSON Mutation using 'jq'
# We read the existing upstream file, inject our custom variables into the keys,
# and leave underlying upstream keys (like "base-image-name") perfectly intact.
INFO_FILE="/usr/share/ublue-os/image-info.json"

jq --arg name "$FINAL_IMAGE_NAME" \
   --arg flavor "$FLAVOR" \
   --arg vendor "$VENDOR" \
   --arg ref "ostree-image-signed:docker://${FINAL_REGISTRY}/${FINAL_IMAGE_NAME}" \
   --arg tag "$FINAL_TAG" \
   --arg fver "$OS_VERSION" \
   '. | .["image-name"] = $name | .["image-flavor"] = $flavor | .["image-vendor"] = $vendor | .["image-ref"] = $ref | .["image-tag"] = $tag | .["fedora-version"] = $fver' \
   "$INFO_FILE" > /tmp/image-info-patched.json

# Overwrite the original file with our safely mutated version
mv /tmp/image-info-patched.json "$INFO_FILE"


# 3. Overwrite the Markdown template for the terminal
cat <<'EOF' > /usr/share/ublue-os/motd/template.md
# 🌍 Welcome to Geonix

🚀 `${MOTD_IMAGE_NAME}:${MOTD_IMAGE_TAG}`

|  Command | Description |
| ------- | ----------- |
| `gj --choose`     | Show available system commands  |
| `gj toggle-user-motd` | Toggle this banner on/off |
| `qgis`            | Launch QGIS Desktop |
| `grass`           | Launch GRASS GIS |

${MOTD_TIP}

- **󰊤** [Geonix Repository](https://github.com/a2rk313/geonix)
- **󰊤** [Report an Issue](https://github.com/a2rk313/geonix/issues)
EOF

# --- 8. SYSTEM CLI BRANDING (UJUST -> GJ) ---
echo "--> Rebranding ujust to gj CLI..."

# 1. Inject the root Justfile
CUSTOM_REPO_JUSTFILE="/ctx/Justfile"

if [ -f "$CUSTOM_REPO_JUSTFILE" ]; then
    echo "--> Custom Justfile detected at root. Injecting into OS..."
    cp "$CUSTOM_REPO_JUSTFILE" /usr/share/ublue-os/just/60-custom.just
else
    echo "--> No custom Justfile found at $CUSTOM_REPO_JUSTFILE. Skipping injection..."
fi

# 2. Overwrite the Master Entry Justfile
# We strip out the upstream URLs and replace them with Geonix branding.
cat <<'EOF' > /usr/share/ublue-os/just/00-entry.just
set allow-duplicate-recipes := true
set ignore-comments := true

_default:
    #!/usr/bin/bash
    echo "🌍 Welcome to Geonix OS Commands"
    echo "Docs: https://github.com/a2rk313/geonix"
    echo ""
    gj --list --list-heading $'Available commands:\n' --list-prefix $' - '

# Imports
import "/usr/share/ublue-os/just/apps.just"
import "/usr/share/ublue-os/just/changelog.just"
import "/usr/share/ublue-os/just/default.just"
import "/usr/share/ublue-os/just/shared.just"
import "/usr/share/ublue-os/just/system.just"
import "/usr/share/ublue-os/just/update.just"
import? "/usr/share/ublue-os/just/60-custom.just"
EOF

# 3. Create the 'gj' shortcut safely
# We do NOT forge a new file, and we do NOT overwrite ujust.
# We create a symlink named 'gj' that simply points to the existing 'ujust' binary.
ln -s /usr/bin/ujust /usr/bin/gj
