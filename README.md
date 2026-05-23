# Geonix

<p align="center">
  <img src="logo/logo.png" alt="Geonix Logo" width="200"/>
</p>

A Universal Blue based distro made for the cool folks that use GIS and Remote Sensing knowledge to make the world a better place.

Ready-to-use Fedora Atomic desktop images pre-loaded with a comprehensive GIS software stack. Available in two variants:

| Variant | Desktop | Base Image | Image |
|---------|---------|-----------|-------|
| **Geonix GNOME** | GNOME | [Bluefin](https://github.com/ublue-os/bluefin) | `ghcr.io/a2rk313/geonix-gnome` |
| **Geonix Plasma** | KDE Plasma | [Aurora](https://github.com/ublue-os/aurora) | `ghcr.io/a2rk313/geonix-plasma` |

## Included Software

- **Desktop GIS**: [QGIS](https://qgis.org/) with Python bindings, [GRASS GIS](https://grass.osgeo.org/), [SAGA GIS](https://saga-gis.sourceforge.io/)
- **Geospatial Libraries**: [GDAL](https://gdal.org/), [GEOS](https://libgeos.org/), [PROJ](https://proj.org/), [LibGEOTIFF](https://geotiff.github.io/libgeotiff/), [LibSpatialite](https://www.gaia-gis.it/fossil/libspatialite/), [SpatialIndex](https://libspatialindex.github.io/)
- **Databases**: [PostgreSQL](https://www.postgresql.org/) with [PostGIS](https://postgis.net/)
- **Python**: [Shapely](https://shapely.readthedocs.io/), [Fiona](https://fiona.readthedocs.io/), [Pandas](https://pandas.pydata.org/), [NumPy](https://numpy.org/)

## Quick Start

### Switch to Geonix from an Existing bootc System

```bash
# GNOME variant
sudo bootc switch ghcr.io/a2rk313/geonix-gnome:latest

# KDE Plasma variant
sudo bootc switch ghcr.io/a2rk313/geonix-plasma:latest
```

Reboot after the command completes.

### Install via ISO

Download a disk image from the [GitHub Releases](https://github.com/a2rk313/geonix/releases) or [ArtifactHub](https://artifacthub.io/) page. Boot from the ISO and install normally — the installer will deploy the latest Geonix image.

## Building Locally

You need [Podman](https://podman.io/) and [just](https://just.systems/) installed.

```bash
# Build the GNOME variant
just build-bluefin

# Build the KDE variant
just build-aurora

# Build both
just build-all

# Build with a custom base image
just build geonix-gnome latest ghcr.io/ublue-os/bluefin:stable
```

### Build Disk Images (ISO / QCOW2 / RAW)

```bash
# QCOW2 virtual machine image (GNOME)
just build-qcow2

# RAW image (GNOME)
just build-raw

# Installer ISO (KDE)
just build-iso-kde

# Installer ISO (GNOME)
just build-iso-gnome
```

### Run in a VM

```bash
# Run QCOW2 image in a VM (via qemux)
just run-vm-qcow2

# Run using systemd-vmspawn (faster)
just spawn-vm

# Run the KDE installer ISO in a VM
just run-vm-iso-kde
```

## Repository Structure

| Path | Description |
|------|-------------|
| `Containerfile` | Image build definition |
| `build_files/build.sh` | Package installation and system configuration |
| `Justfile` | Build, VM, and utility commands |
| `disk_config/` | Bootc image builder configuration (disk sizing, kickstart) |
| `.github/workflows/build.yml` | CI workflow to build and publish container images |
| `.github/workflows/build-disk.yml` | CI workflow to build disk images (ISO, QCOW2, RAW) |
| `cosign.pub` | Public key for container image signature verification |

## License

[Apache 2.0](LICENSE)
