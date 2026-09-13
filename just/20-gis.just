# ─── GIS Workstation: Status ───────────────────────────────────────────────────

# Show what has been installed via opt-in recipes
[group('GIS Workstation')]
gis-status:
    #!/usr/bin/bash
    echo "=== Geonix — Installed Recipes ==="
    STATE_DIR="${HOME}/.config/geonix"
    if [ ! -d "$STATE_DIR" ] || [ -z "$(ls -A "$STATE_DIR" 2>/dev/null)" ]; then
        echo "  No optional recipes installed yet."
        echo "  Run 'just --list' to see available recipes."
    else
        for f in "$STATE_DIR"/*.installed; do
            [ -f "$f" ] || continue
            name=$(basename "$f" .installed)
            date=$(cat "$f")
            echo "  [x] ${name}  (installed: ${date})"
        done
    fi

# Internal: write an install marker
[private]
_mark-installed name:
    #!/usr/bin/bash
    mkdir -p "${HOME}/.config/geonix"
    echo "$(date -I)" > "${HOME}/.config/geonix/{{ name }}.installed"

# ─── GIS Workstation: Desktop GIS ──────────────────────────────────────────────

# Install Orfeo Toolbox
[group('GIS Workstation')]
install-otb:
    #!/usr/bin/bash
    set -euo pipefail
    echo "=== Installing Orfeo Toolbox ==="
    sudo apt update
    sudo apt install -y otb-bin otb-bin-python
    just _mark-installed otb
    echo "OTB installed."
    echo "  Test: otbcli_Smoothing -help"

# Install WhiteboxTools binary
[group('GIS Workstation')]
install-whitebox:
    #!/usr/bin/bash
    set -euo pipefail
    echo "=== Installing WhiteboxTools ==="
    INSTALL_DIR="${HOME}/.local/bin"
    mkdir -p "$INSTALL_DIR"
    LATEST=$(curl -s https://api.github.com/repos/jblindsay/whitebox-tools/releases/latest \
        | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    echo "Version: ${LATEST}"
    cd /tmp
    curl -L -o whitebox_tools.tar.gz \
        "https://github.com/jblindsay/whitebox-tools/releases/download/${LATEST}/WhiteboxTools_linux_musl.tar.gz"
    tar -xzf whitebox_tools.tar.gz
    mv WhiteboxTools_linux_musl/whitebox_tools "${INSTALL_DIR}/"
    chmod +x "${INSTALL_DIR}/whitebox_tools"
    rm -rf whitebox_tools.tar.gz WhiteboxTools_linux_musl/
    just _mark-installed whitebox
    echo "WhiteboxTools ${LATEST} installed to ${INSTALL_DIR}"

# Install CloudCompare via Flatpak
[group('GIS Workstation')]
install-cloudcompare:
    #!/usr/bin/bash
    set -euo pipefail
    flatpak install -y flathub org.cloudcompare.CloudCompare
    just _mark-installed cloudcompare
    echo "CloudCompare installed."

# Install essential QGIS plugins
[group('GIS Workstation')]
install-qgis-plugins:
    #!/usr/bin/bash
    set -euo pipefail
    echo "=== Installing QGIS Plugins ==="
    PLUGIN_DIR="${HOME}/.local/share/QGIS/QGIS3/profiles/default/python/plugins"
    mkdir -p "$PLUGIN_DIR"
    pip3 install --user --break-system-packages qgis-plugin-manager
    cd "$PLUGIN_DIR"
    qgis-plugin-manager init --qgis-version auto --update
    qgis-plugin-manager install QuickMapServices
    just _mark-installed qgis-plugins
    echo "QGIS plugins installed."

# ─── GIS Workstation: Databases & Servers ──────────────────────────────────────

# Install PostgreSQL + PostGIS
[group('GIS Workstation')]
install-postgis:
    #!/usr/bin/bash
    set -euo pipefail
    echo "=== Installing PostgreSQL + PostGIS ==="
    sudo apt update
    sudo apt install -y postgresql postgresql-16-postgis-3
    just _mark-installed postgis
    echo "PostGIS installed."
    echo "  Run: just setup-postgis-db"

# Initialize PostGIS database
[group('GIS Workstation')]
setup-postgis-db:
    #!/usr/bin/bash
    set -euo pipefail
    sudo systemctl enable --now postgresql
    read -rp "Create a PostGIS database and user? [Y/n] " create_db
    if [[ ! "$create_db" =~ ^[Nn]$ ]]; then
        read -rp "Database name [default: gis]: " db_name
        db_name="${db_name:-gis}"
        read -rp "Username [default: gis]: " db_user
        db_user="${db_user:-gis}"
        read -rsp "Password [default: gis]: " db_pass
        echo ""
        db_pass="${db_pass:-gis}"
        sudo -u postgres psql -c "CREATE USER \"$db_user\" WITH PASSWORD '$db_pass' CREATEDB;" 2>/dev/null || true
        sudo -u postgres psql -c "CREATE DATABASE \"$db_name\" OWNER \"$db_user\";" 2>/dev/null || true
        sudo -u postgres psql -d "$db_name" -c "CREATE EXTENSION IF NOT EXISTS postgis;" 2>/dev/null || true
        echo ""
        echo "PostGIS running. Connect: psql -U ${db_user} -d ${db_name}"
    fi

# ─── GIS Workstation: Python & Notebooks ───────────────────────────────────────

# Install JupyterLab with GIS kernel
[group('GIS Workstation')]
install-jupyter:
    #!/usr/bin/bash
    set -euo pipefail
    echo "=== Installing JupyterLab ==="
    VENV_DIR="${HOME}/.local/share/geonix/jupyter-env"
    python3 -m venv "$VENV_DIR"
    "$VENV_DIR/bin/pip" install --upgrade pip
    "$VENV_DIR/bin/pip" install \
        jupyterlab ipywidgets ipyleaflet \
        folium mapclassify contextily \
        geopandas rasterio xarray \
        numpy pandas matplotlib scipy
    "$VENV_DIR/bin/python" -m ipykernel install \
        --user --name gis-kernel --display-name "GIS Python"
    mkdir -p "${HOME}/.local/bin"
    printf '%s\n' \
        '#!/bin/bash' \
        "source \"${VENV_DIR}/bin/activate\"" \
        'jupyter lab "$@"' \
        > "${HOME}/.local/bin/gis-lab"
    chmod +x "${HOME}/.local/bin/gis-lab"
    just _mark-installed jupyter
    echo "JupyterLab installed. Launch: gis-lab"

# ─── GIS Workstation: Workflow Bundles ─────────────────────────────────────────

# Remote Sensing bundle
[group('GIS Workstation')]
install-bundle-rs:
    just install-otb
    just install-jupyter
    @echo "Remote Sensing bundle complete."

# LiDAR bundle
[group('GIS Workstation')]
install-bundle-lidar:
    just install-whitebox
    just install-cloudcompare
    @echo "LiDAR bundle complete."

# GeoAI bundle
[group('GIS Workstation')]
install-bundle-geoai:
    just install-jupyter
    @echo "GeoAI bundle complete."

# Web GIS bundle
[group('GIS Workstation')]
install-bundle-webgis:
    just install-postgis
    @echo "Web GIS bundle complete."
    @echo "Run 'just setup-postgis-db' after install."
