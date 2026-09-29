#!/bin/bash
set -euxo pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.

dnf5 install -y \
  "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
  "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

# copr.vendor.conf pins the COPR plugin to `distribution = fedora` so
# `dnf5 copr enable` works under our custom ID=geonix os-release (bluefin PR #17).
# MUST run before any `dnf5 copr enable`.
install -Dm644 /ctx/copr.vendor.conf /usr/share/dnf/plugins/copr.vendor.conf

dnf5 -y copr enable ublue-os/packages
dnf5 -y copr enable megger/saga

# GIS stack from Fedora repos (+ SAGA from megger/saga COPR enabled above)
dnf5 install -y \
  uupd \
  ublue-os-update-services \
  ublue-os-signing \
  ublue-os-just \
  just jq \
  gdal \
  proj proj-data \
  geos libgeotiff \
  qgis python3-qgis \
  qgis-grass grass \
  grass-gui python3-shapely \
  python3-fiona \
  python3-pyproj \
  python3-rasterio \
  python3-geopandas \
  python3-xarray \
  python3-netcdf4 \
  python3-matplotlib \
  python3-scipy \
  pdal \
  liblas \
  python3-h5py \
  gpsd gpsbabel \
  saga \
  python3-scikit-learn \
  python3-numpy \
  python3-pandas \
  python3-sqlalchemy \
  libspatialite spatialite-tools \
  spatialindex \
  python3-wxpython &&
  dnf5 clean all

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

if [[ ! -e /usr/bin/ujust ]]; then ln -sf /usr/bin/just /usr/bin/ujust; fi
dnf5 -y copr disable ublue-os/packages

dnf5 -y copr disable megger/saga

# Enabled systemd services
systemctl enable podman.socket
