#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

dnf5 -y copr enable megger/saga

# this installs a package from fedora repos
dnf5 install -y gdal gdal-python3 geos proj proj-data libgeotiff libspatialite spatialite-tools spatialindex postgis postgresql qgis python3-qgis qgis-grass grass saga \
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

# We copy the logo from the temporarily mounted GitHub repository (/ctx)
# using your exact repository structure into the core Plymouth system directories.
cp /ctx/logo/logo.png /usr/share/plymouth/themes/spinner/watermark.png
cp /ctx/logo/logo.png /usr/share/plymouth/themes/spinner/bgrt-fallback.png

# --- 5. DESKTOP ENVIRONMENT BRANDING (GNOME & KDE) ---
echo "--> Applying DE panel logos..."

# 1. Place the Geonix logo in the standard system application icon directory
mkdir -p /usr/share/icons/hicolor/scalable/apps/
cp /ctx/logo/logo.png /usr/share/icons/hicolor/scalable/apps/geonix-logo.png


# 2. GNOME: Inject dconf override for the Logo Menu extension
echo "--> Configuring GNOME Logo Menu..."
cat <<EOF > /usr/share/glib-2.0/schemas/99-geonix-logo.gschema.override
[org.gnome.shell.extensions.Logo-menu]
# Value 2 tells the extension to use a custom image path
menu-button-icon-image=2
# Define the absolute path to your Geonix logo
custom-icon-path='/usr/share/icons/hicolor/scalable/apps/geonix-logo.png'
EOF

# Compile the schemas so GNOME enforces the new default on the next boot
glib-compile-schemas /usr/share/glib-2.0/schemas/


# 3. KDE Plasma: Hijack the default 'start-here' distribution icons
echo "--> Configuring KDE Plasma Kickoff icon..."
mkdir -p /usr/share/icons/hicolor/scalable/places/

# Overwrite the standard Linux start menu icons with the Geonix logo
cp /ctx/logo/logo.png /usr/share/icons/hicolor/scalable/places/start-here.png
cp /ctx/logo/logo.png /usr/share/icons/hicolor/scalable/places/start-here-kde.png

# Rebuild the system icon cache so both DEs immediately recognize the new files
gtk-update-icon-cache -f -t /usr/share/icons/hicolor || true
