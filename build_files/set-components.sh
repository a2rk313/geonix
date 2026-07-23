#!/usr/bin/bash
set -ouex pipefail

echo "Setting user.component xattrs for chunked OCI layer assignment..."

# Foundational geospatial libraries
setfattr -n user.component -v "gdal"     /usr/lib64/libgdal.so*          2>/dev/null || true
setfattr -n user.component -v "gdal"     /usr/share/gdal                 2>/dev/null || true
setfattr -n user.component -v "proj"     /usr/share/proj                 2>/dev/null || true
setfattr -n user.component -v "proj"     /usr/lib64/libproj*             2>/dev/null || true
setfattr -n user.component -v "geos"     /usr/lib64/libgeos*             2>/dev/null || true

# QGIS
setfattr -n user.component -v "qgis"     /usr/share/qgis                 2>/dev/null || true
setfattr -n user.component -v "qgis"     /usr/lib64/qgis                 2>/dev/null || true
setfattr -n user.component -v "qgis"     /usr/bin/qgis*                  2>/dev/null || true

# GRASS GIS
setfattr -n user.component -v "grass"    /usr/share/grass*               2>/dev/null || true
setfattr -n user.component -v "grass"    /usr/lib64/grass*               2>/dev/null || true
setfattr -n user.component -v "grass"    /usr/bin/grass*                 2>/dev/null || true

# SAGA GIS
setfattr -n user.component -v "saga"     /usr/share/saga*                2>/dev/null || true
setfattr -n user.component -v "saga"     /usr/lib64/saga*                2>/dev/null || true
setfattr -n user.component -v "saga"     /usr/bin/saga_cmd               2>/dev/null || true

# GRASS GIS Python
setfattr -n user.component -v "grass"    /usr/lib64/grass*/etc/python*   2>/dev/null || true

# SAGA GIS Python
setfattr -n user.component -v "saga"     /usr/lib64/saga/python*         2>/dev/null || true

# PDAL
setfattr -n user.component -v "pdal"     /usr/lib64/libpdal*             2>/dev/null || true
setfattr -n user.component -v "pdal"     /usr/bin/pdal                   2>/dev/null || true

# Python GIS stack
setfattr -n user.component -v "gis-py"   /usr/lib/python3*/site-packages/fiona*      2>/dev/null || true
setfattr -n user.component -v "gis-py"   /usr/lib/python3*/site-packages/rasterio*   2>/dev/null || true
setfattr -n user.component -v "gis-py"   /usr/lib/python3*/site-packages/shapely*    2>/dev/null || true
setfattr -n user.component -v "gis-py"   /usr/lib/python3*/site-packages/geopandas*  2>/dev/null || true
setfattr -n user.component -v "gis-py"   /usr/lib/python3*/site-packages/pyproj*     2>/dev/null || true
setfattr -n user.component -v "gis-py"   /usr/lib/python3*/site-packages/xarray*     2>/dev/null || true
setfattr -n user.component -v "gis-py"   /usr/lib/python3*/site-packages/netCDF4*    2>/dev/null || true
setfattr -n user.component -v "gis-py"   /usr/lib/python3*/site-packages/h5py*       2>/dev/null || true
setfattr -n user.component -v "gis-py"   /usr/lib/python3*/site-packages/scipy*      2>/dev/null || true
setfattr -n user.component -v "gis-py"   /usr/lib/python3*/site-packages/sklearn*    2>/dev/null || true
setfattr -n user.component -v "gis-py"   /usr/lib/python3*/site-packages/sqlalchemy* 2>/dev/null || true

# Branding — changes most frequently, isolated so updates don't touch GIS layers
# Plymouth theme assets
setfattr -n user.component -v "branding" /usr/share/plymouth/themes/spinner/watermark.png 2>/dev/null || true
setfattr -n user.component -v "branding" /usr/share/plymouth/themes/spinner/bgrt-fallback.png 2>/dev/null || true
setfattr -n user.component -v "branding" /usr/share/plymouth/themes/spinner/silverblue-watermark.png 2>/dev/null || true
setfattr -n user.component -v "branding" /usr/share/plymouth/themes/spinner/silverblue-logo.png 2>/dev/null || true

# System icon
setfattr -n user.component -v "branding" /usr/share/icons/hicolor/scalable/apps/geonix-logo.png 2>/dev/null || true

# GDM / Pixmaps replacement assets
setfattr -n user.component -v "branding" /usr/share/pixmaps/fedora-gdm-logo.png 2>/dev/null || true
setfattr -n user.component -v "branding" /usr/share/pixmaps/fedora-logo.png 2>/dev/null || true
setfattr -n user.component -v "branding" /usr/share/pixmaps/fedora-logo-icon.png 2>/dev/null || true
setfattr -n user.component -v "branding" /usr/share/pixmaps/fedora-logo-small.png 2>/dev/null || true
setfattr -n user.component -v "branding" /usr/share/pixmaps/fedora-logo-sprite.png 2>/dev/null || true
setfattr -n user.component -v "branding" /usr/share/pixmaps/fedora_logo_med.png 2>/dev/null || true
setfattr -n user.component -v "branding" /usr/share/pixmaps/fedora_whitelogo_med.png 2>/dev/null || true
