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

cp /build-assets/logo/logo.png /usr/share/plymouth/themes/spinner/watermark.png
cp /build-assets/logo/logo.png /usr/share/plymouth/themes/spinner/bgrt-fallback.png


# --- 5. DESKTOP ENVIRONMENT BRANDING (GNOME & KDE) ---
echo "--> Applying DE panel logos..."

mkdir -p /usr/share/icons/hicolor/scalable/apps/
cp /build-assets/logo/logo.png /usr/share/icons/hicolor/scalable/apps/geonix-logo.png

echo "--> Configuring GNOME Logo Menu..."
cat <<EOF > /usr/share/glib-2.0/schemas/99-geonix-logo.gschema.override
[org.gnome.shell.extensions.Logo-menu]
menu-button-icon-image=2
custom-icon-path='/usr/share/icons/hicolor/scalable/apps/geonix-logo.png'
EOF
glib-compile-schemas /usr/share/glib-2.0/schemas/

echo "--> Configuring KDE Plasma Kickoff icon..."
mkdir -p /usr/share/icons/hicolor/scalable/places/
cp /build-assets/logo/logo.png /usr/share/icons/hicolor/scalable/places/start-here.png
cp /build-assets/logo/logo.png /usr/share/icons/hicolor/scalable/places/start-here-kde.png

gtk-update-icon-cache -f -t /usr/share/icons/hicolor || true

# --- 6. CLEANUP ---
# Delete the staging directory so the logo is not duplicated in the final OS image
rm -rf /build-assets
