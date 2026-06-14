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

# Enabled systemd services
systemctl enable podman.socket

# Fix for ID= parameter for osbuild
if [ -f /usr/lib/os-release.d/os-release-fedora ]; then
    sed -i 's/^ID=.*$/ID=fedora/' /usr/lib/os-release.d/os-release-fedora
fi

echo 'VARIANT_ID="geonix"' >> /usr/lib/os-release
echo 'NAME="Geonix"' >> /usr/lib/os-release

source /ctx/image-info.sh
source /ctx/branding.sh
