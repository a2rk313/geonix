#!/bin/bash
set -euxo pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images

dnf5 -y copr enable megger/saga

# this installs a package from fedora repos
dnf5 install -y \
    gdal \
    proj proj-data \
    geos libgeotiff \
    qgis python3-qgis \
    qgis-grass grass \
    python3-shapely \
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
