# ─── GIS Workstation: Status ───────────────────────────────────────────────────

# Show what has been installed via opt-in recipes
[group('GIS Workstation')]
status:
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

# Internal: rpm-ostree install with --apply-live fallback
[private]
_ostree-install +packages:
    #!/usr/bin/bash
    echo "Layering onto host OSTree: {{ packages }}"
    echo "Attempting --apply-live (no reboot)..."
    if sudo rpm-ostree install --idempotent --apply-live {{ packages }}; then
        echo "  Applied live — no reboot needed."
    else
        echo ""
        echo "  --apply-live failed (complex deps or kernel-adjacent package)."
        echo "  Queuing for next boot instead..."
        sudo rpm-ostree install --idempotent {{ packages }}
        echo ""
        echo "  REBOOT REQUIRED to complete installation."
        echo "  Run: systemctl reboot"
    fi

# ─── GIS Workstation: Desktop GIS ──────────────────────────────────────────────

# Install Orfeo Toolbox — latest available from orfeotoolbox COPR
[group('GIS Workstation')]
install-otb:
    #!/usr/bin/bash
    set -euo pipefail
    echo "=== Installing Orfeo Toolbox (OTB) ==="
    echo "Use case: Sentinel-1/2, multispectral classification, SAR"
    echo "This layers packages onto the host — a reboot may be required."
    echo ""
    FEDORA_VER=$(rpm -E %fedora)

    # Find the latest OTB COPR from orfeotoolbox dynamically
    COPR_NAME=$(curl -s "https://copr.fedorainfracloud.org/api_3/project/search?query=otb&owner=orfeotoolbox" \
        | python3 -c "
    import sys, json
    data = json.load(sys.stdin)
    projects = [p['name'] for p in data.get('items', []) if p['name'].startswith('otb')]
    projects.sort(reverse=True)
    print(projects[0] if projects else 'otb')
    ")
    echo "Using COPR: orfeotoolbox/${COPR_NAME}"
    REPO_URL="https://copr.fedorainfracloud.org/coprs/orfeotoolbox/${COPR_NAME}/repo/fedora-${FEDORA_VER}/orfeotoolbox-${COPR_NAME}-fedora-${FEDORA_VER}.repo"

    sudo rpm-ostree install --idempotent --apply-live \
        --install-from-repo="$REPO_URL" \
        otb || {
        echo ""
        echo "  --apply-live failed. Queuing for next boot..."
        sudo rpm-ostree install --idempotent \
            --install-from-repo="$REPO_URL" \
            otb
        echo ""
        echo "  REBOOT REQUIRED to complete installation."
        echo "  Run: systemctl reboot"
    }
    just _mark-installed otb
    echo ""
    echo "OTB installed from orfeotoolbox/${COPR_NAME}"
    echo "  After reboot: otbcli_Smoothing -help"
    echo "  QGIS: Processing > Options > Providers > OTB"

# Install WhiteboxTools binary to ~/.local/bin — no root, takes effect immediately
[group('GIS Workstation')]
install-whitebox:
    #!/usr/bin/bash
    set -euo pipefail
    echo "=== Installing WhiteboxTools ==="
    echo "Use case: DEM analysis, hydrology, terrain derivatives"
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
    echo ""
    echo "WhiteboxTools ${LATEST} installed to ${INSTALL_DIR}"
    echo "  Test: whitebox_tools --toolbox 'Terrain Analysis'"

# Update WhiteboxTools to latest release
[group('GIS Workstation')]
update-whitebox:
    #!/usr/bin/bash
    CURRENT=$(whitebox_tools --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
    LATEST=$(curl -s https://api.github.com/repos/jblindsay/whitebox-tools/releases/latest \
        | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/')
    echo "Installed: ${CURRENT:-unknown}   Latest: ${LATEST}"
    [[ "$CURRENT" == "$LATEST" ]] && echo "Already up to date." || just install-whitebox

# Update QField AppImage to latest release
[group('GIS Workstation')]
update-qfield:
    #!/usr/bin/bash
    INSTALL_DIR="${HOME}/.local/bin"
    LATEST=$(curl -s https://api.github.com/repos/opengisch/QField/releases/latest \
        | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/')
    echo "Downloading QField ${LATEST}..."
    curl -L -o "${INSTALL_DIR}/QField.AppImage" \
        "https://github.com/opengisch/QField/releases/download/v${LATEST}/qfield-v${LATEST}-linux-x64.AppImage"
    chmod +x "${INSTALL_DIR}/QField.AppImage"
    echo "QField updated to ${LATEST}"

# Install CloudCompare via Flatpak — no native RPM available
[group('GIS Workstation')]
install-cloudcompare:
    #!/usr/bin/bash
    set -euo pipefail
    flatpak install -y flathub org.cloudcompare.CloudCompare
    just _mark-installed cloudcompare
    echo "CloudCompare installed."
    echo "  Supports: LAS/LAZ, E57, PLY, OBJ, SHP"

# Install essential QGIS plugins — run once after first boot
[group('GIS Workstation')]
install-qgis-plugins:
    #!/usr/bin/bash
    set -euo pipefail
    echo "=== Installing QGIS Plugins ==="
    PLUGIN_DIR="${HOME}/.local/share/QGIS/QGIS3/profiles/default/python/plugins"
    QGIS_INI="${HOME}/.local/share/QGIS/QGIS3/profiles/default/QGIS/QGIS.ini"
    mkdir -p "$PLUGIN_DIR"
    mkdir -p "$(dirname "$QGIS_INI")"
    pip3 install --user --break-system-packages qgis-plugin-manager
    # Init sources.list with QGIS version auto-detection
    cd "$PLUGIN_DIR"
    qgis-plugin-manager init --qgis-version auto --update
    # Install plugins
    echo "Installing QuickMapServices..."
    qgis-plugin-manager install QuickMapServices
    # Enable plugins in QGIS.ini
    if ! grep -q "\[PythonPlugins\]" "$QGIS_INI" 2>/dev/null; then
        echo "[PythonPlugins]" >> "$QGIS_INI"
    fi
    if ! grep -q "QuickMapServices" "$QGIS_INI"; then
        sed -i '/\[PythonPlugins\]/a QuickMapServices=true' "$QGIS_INI"
    fi
    just _mark-installed qgis-plugins
    echo ""
    echo "QGIS plugins installed and enabled."
    echo "  Restart QGIS to load plugins."

# Update installed QGIS plugins
[group('GIS Workstation')]
update-qgis-plugins:
    #!/usr/bin/bash
    set -euo pipefail
    PLUGIN_DIR="${HOME}/.local/share/QGIS/QGIS3/profiles/default/python/plugins"
    cd "$PLUGIN_DIR"
    pip3 install --user --break-system-packages --upgrade qgis-plugin-manager
    qgis-plugin-manager update
    qgis-plugin-manager upgrade
    echo "QGIS plugins updated."

# ─── GIS Workstation: Point Cloud & Terrain ────────────────────────────────────

# Install PROJ datum grids for accurate coordinate transformations — no root required
[group('GIS Workstation')]
install-proj-grids:
    #!/usr/bin/bash
    set -euo pipefail
    echo "=== Installing PROJ Datum Grids ==="
    echo ""
    echo "Select regions to download (space-separated numbers, e.g. '1 3'):"
    echo "  1) North America"
    echo "  2) Europe"
    echo "  3) Asia"
    echo "  4) Oceania"
    echo "  5) Africa"
    echo "  6) Antarctica"
    echo "  7) World (all regions, ~600MB)"
    echo ""
    read -rp "Regions: " selections
    echo ""

    GRID_DIR="${HOME}/.local/share/proj"
    mkdir -p "$GRID_DIR"

    declare -A region_map=(
        [1]="north-america"
        [2]="europe"
        [3]="asia"
        [4]="oceania"
        [5]="africa"
        [6]="antarctica"
        [7]="world"
    )

    for sel in $selections; do
        region="${region_map[$sel]:-}"
        if [[ -z "$region" ]]; then
            echo "Unknown selection: $sel — skipping"
            continue
        fi
        echo "Downloading: $region"
        projsync --target-dir "$GRID_DIR" --region "$region"
    done

    if ! grep -q "PROJ_NETWORK" "${HOME}/.bashrc"; then
        echo "export PROJ_NETWORK=ON" >> "${HOME}/.bashrc"
        echo "export PROJ_DATA=${GRID_DIR}:/usr/share/proj" >> "${HOME}/.bashrc"
    fi

    just _mark-installed proj-grids
    echo ""
    echo "PROJ datum grids installed to ${GRID_DIR}"
    echo "  Restart shell or: source ~/.bashrc"

# ─── GIS Workstation: Databases & Servers ──────────────────────────────────────

# Install PostgreSQL + PostGIS — reboot may be required before setup
[group('GIS Workstation')]
install-postgis:
    #!/usr/bin/bash
    set -euo pipefail
    echo "=== Installing PostgreSQL + PostGIS ==="
    echo "This layers packages onto the host — a reboot may be required."
    echo "  After rebooting run: just setup-postgis-db"
    echo ""
    just _ostree-install postgresql postgresql-server postgis
    just _mark-installed postgis

# Initialize PostGIS database — run this after rebooting post install-postgis
[group('GIS Workstation')]
setup-postgis-db:
    #!/usr/bin/bash
    set -euo pipefail
    if [ ! -f /var/lib/pgsql/data/PG_VERSION ]; then
        sudo postgresql-setup --initdb
    fi
    sudo systemctl enable --now postgresql
    read -rp "Create a PostGIS database and user? [Y/n] " create_db
    if [[ ! "$create_db" =~ ^[Nn]$ ]]; then
        read -rp "Database name [default: gis]: " db_name
        db_name="${db_name:-gis}"
        read -rp "Username [default: gis]: " db_user
        db_user="${db_user:-gis}"
        read -rsp "Password (Will not be visible as you type) [default: gis]: " db_pass
        echo ""
        db_pass="${db_pass:-gis}"

        sudo -u postgres psql -c "CREATE USER \"$db_user\" WITH PASSWORD '$db_pass' CREATEDB;" 2>/dev/null || true
        sudo -u postgres psql -c "CREATE DATABASE \"$db_name\" OWNER \"$db_user\";" 2>/dev/null || true
        sudo -u postgres psql -d "$db_name" -c "CREATE EXTENSION IF NOT EXISTS postgis;" 2>/dev/null || true
        sudo -u postgres psql -d "$db_name" -c "CREATE EXTENSION IF NOT EXISTS postgis_topology;" 2>/dev/null || true
        echo ""
        echo "PostGIS running."
        echo "  Connect: psql -U ${db_user} -d ${db_name}"
        echo "  QGIS: Host=localhost DB=${db_name} User=${db_user} Pass=${db_pass}"
    fi

# Install GeoServer as a systemd Quadlet container — takes effect immediately
[group('GIS Workstation')]
install-geoserver:
    #!/usr/bin/bash
    set -euo pipefail
    GEOSERVER_VERSION=$(curl -s "https://api.github.com/repos/geoserver/geoserver/releases/latest" \
        | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/^v//')
    echo "=== Installing GeoServer ${GEOSERVER_VERSION} (Quadlet) ==="
    mkdir -p "${HOME}/.config/containers/systemd"
    mkdir -p "${HOME}/geoserver-data"
    printf '%s\n' \
        "[Unit]" \
        "Description=GeoServer OGC Map Server" \
        "After=network-online.target" \
        "" \
        "[Container]" \
        "Image=docker.io/kartoza/geoserver:${GEOSERVER_VERSION}" \
        "PublishPort=8080:8080" \
        "Volume=%h/geoserver-data:/opt/geoserver/data_dir:Z" \
        "Environment=GEOSERVER_DATA_DIR=/opt/geoserver/data_dir" \
        "" \
        "[Service]" \
        "Restart=on-failure" \
        "" \
        "[Install]" \
        "WantedBy=default.target" \
        > "${HOME}/.config/containers/systemd/geoserver.container"
    systemctl --user daemon-reload
    systemctl --user enable --now geoserver
    just _mark-installed geoserver
    echo ""
    echo "GeoServer running as a user Quadlet."
    echo "  Status: systemctl --user status geoserver"
    echo "  Web UI: http://localhost:8080/geoserver  (admin/geoserver)"
    echo "  Data:   ~/geoserver-data"

# Install MapProxy in an isolated venv — no root, takes effect immediately
[group('GIS Workstation')]
install-mapproxy:
    #!/usr/bin/bash
    set -euo pipefail
    echo "=== Installing MapProxy ==="
    VENV_DIR="${HOME}/.local/share/geonix/mapproxy-env"
    python3 -m venv "$VENV_DIR"
    "$VENV_DIR/bin/pip" install --upgrade pip mapproxy Pillow pyproj
    mkdir -p "${HOME}/.local/bin"
    printf '%s\n' \
        '#!/bin/bash' \
        "source \"${VENV_DIR}/bin/activate\"" \
        'mapproxy-util "$@"' \
        > "${HOME}/.local/bin/mapproxy"
    chmod +x "${HOME}/.local/bin/mapproxy"
    CONF_DIR="${HOME}/.config/mapproxy"
    mkdir -p "$CONF_DIR"
    [ -f "${CONF_DIR}/mapproxy.yaml" ] || \
        "$VENV_DIR/bin/mapproxy-util" create -t base-config "$CONF_DIR/"
    just _mark-installed mapproxy
    echo "MapProxy installed."
    echo "  Config: ${CONF_DIR}/mapproxy.yaml"
    echo "  Start:  mapproxy serve-develop ${CONF_DIR}/mapproxy.yaml"

# ─── GIS Workstation: Python & Notebooks ───────────────────────────────────────

# Install JupyterLab with GIS kernel in an isolated venv
[group('GIS Workstation')]
install-jupyter:
    #!/usr/bin/bash
    set -euo pipefail
    echo "=== Installing JupyterLab (GIS kernel) ==="
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
    echo "JupyterLab installed."
    echo "  Launch: gis-lab  |  Kernel: 'GIS Python'"

# ─── GIS Workstation: GPU & ML ─────────────────────────────────────────────────

# Install GPU GeoAI stack — flexible GPU detection and CUDA version matching
[group('GIS Workstation')]
install-gpu-ml:
    #!/usr/bin/bash
    set -euo pipefail
    echo "=== Installing GeoAI Stack ==="
    echo ""
    echo "Select compute backend:"
    echo "  1) NVIDIA GPU (auto-detect CUDA version)"
    echo "  2) Intel GPU (XPU / Arc / integrated Xe)"
    echo "  3) CPU only (no GPU, slower but works anywhere)"
    echo ""
    read -rp "Backend [1-3, default: 1]: " backend_sel
    backend_sel="${backend_sel:-1}"
    echo ""

    VENV_DIR="${HOME}/.local/share/geonix/geoai-env"
    python3 -m venv "$VENV_DIR"
    "$VENV_DIR/bin/pip" install --upgrade pip

    case "$backend_sel" in
        1)
            # Auto-detect CUDA version from nvidia-smi
            if ! command -v nvidia-smi &>/dev/null; then
                echo "⚠  nvidia-smi not found. Are you on a geonix-nvidia variant?"
                read -rp "Continue anyway with cu121 fallback? [y/N] " force
                [[ "$force" =~ ^[Yy]$ ]] || exit 0
                CUDA_TAG="cu121"
            else
                CUDA_FULL=$(nvidia-smi 2>/dev/null | grep "CUDA Version" | awk '{print $NF}')
                CUDA_MAJOR=$(echo "$CUDA_FULL" | cut -d. -f1)
                CUDA_MINOR=$(echo "$CUDA_FULL" | cut -d. -f2)
                CUDA_TAG="cu${CUDA_MAJOR}${CUDA_MINOR}"
                echo "Detected CUDA ${CUDA_FULL} → using PyTorch wheel: ${CUDA_TAG}"
                # Validate against known PyTorch wheel tags
                case "$CUDA_TAG" in
                    cu118|cu121|cu124|cu126) ;;
                    *)
                        echo "⚠  ${CUDA_TAG} not a known PyTorch wheel tag."
                        echo "   Known tags: cu118, cu121, cu124, cu126"
                        read -rp "Override wheel tag (or Enter to use ${CUDA_TAG}): " override
                        [[ -n "$override" ]] && CUDA_TAG="$override"
                        ;;
                esac
            fi
            echo "Installing PyTorch with ${CUDA_TAG}..."
            "$VENV_DIR/bin/pip" install torch torchvision torchaudio \
                --index-url "https://download.pytorch.org/whl/${CUDA_TAG}"
            ;;
        2)
            echo "Installing PyTorch for Intel XPU..."
            "$VENV_DIR/bin/pip" install torch torchvision torchaudio \
                --index-url "https://download.pytorch.org/whl/xpu"
            ;;
        3)
            echo "Installing PyTorch CPU-only..."
            "$VENV_DIR/bin/pip" install torch torchvision torchaudio \
                --index-url "https://download.pytorch.org/whl/cpu"
            ;;
        *)
            echo "Invalid selection. Exiting."
            exit 1
            ;;
    esac

    echo ""
    echo "Select package set:"
    echo "  1) Minimal — torchgeo only"
    echo "  2) Full    — torchgeo + segmentation-models + lightning + wandb"
    echo ""
    read -rp "Package set [1-2, default: 2]: " pkg_sel
    pkg_sel="${pkg_sel:-2}"

    "$VENV_DIR/bin/pip" install torchgeo
    if [[ "$pkg_sel" == "2" ]]; then
        "$VENV_DIR/bin/pip" install segmentation-models-pytorch lightning wandb
    fi

    # Activation alias
    if ! grep -q "geoai-env" "${HOME}/.bashrc"; then
        echo "alias geoai='source ${VENV_DIR}/bin/activate'" >> "${HOME}/.bashrc"
    fi

    # Verify install
    echo ""
    "$VENV_DIR/bin/python" -c "
    import torch
    print(f'PyTorch: {torch.__version__}')
    print(f'CUDA available: {torch.cuda.is_available()}')
    if hasattr(torch, 'xpu'):
        print(f'XPU available: {torch.xpu.is_available()}')
    "
        just _mark-installed gpu-ml
        echo ""
        echo "GeoAI stack installed."
        echo "  Activate: geoai  (alias in ~/.bashrc)"
        echo "  Restart shell or: source ~/.bashrc"

# ─── GIS Workstation: Field Tools ──────────────────────────────────────────────

# Install extended field tools: Mergin Maps CLI, GPX tools, QField
[group('GIS Workstation')]
install-fieldwork:
    #!/usr/bin/bash
    set -euo pipefail
    echo "=== Installing Extended Fieldwork Tools ==="
    pip3 install --user mergin-client gpxpy gpx-converter

    # QField desktop companion via AppImage
    read -rp "Install QField desktop companion (AppImage)? [Y/n] " qfield
    if [[ ! "$qfield" =~ ^[Nn]$ ]]; then
        INSTALL_DIR="${HOME}/.local/bin"
        APPS_DIR="${HOME}/.local/share/applications"
        mkdir -p "$INSTALL_DIR" "$APPS_DIR"
        LATEST=$(curl -s https://api.github.com/repos/opengisch/QField/releases/latest \
            | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/')
        echo "Downloading QField ${LATEST}..."
        curl -L -o "${INSTALL_DIR}/QField.AppImage" \
            "https://github.com/opengisch/QField/releases/download/v${LATEST}/qfield-v${LATEST}-linux-x64.AppImage"
        chmod +x "${INSTALL_DIR}/QField.AppImage"
        printf '%s\n' \
            "[Desktop Entry]" \
            "Name=QField" \
            "Comment=Mobile GIS field data collection" \
            "Exec=${INSTALL_DIR}/QField.AppImage" \
            "Icon=qfield" \
            "Type=Application" \
            "Categories=Science;Geography;" \
            > "${APPS_DIR}/qfield.desktop"
        echo "  QField ${LATEST} installed."
        echo "  Launch: QField.AppImage or from app launcher"
    fi

    just _mark-installed fieldwork
    echo "Fieldwork tools installed."
    echo "  Mergin CLI:   mergin --help"
    echo "  Field sync:   https://merginmaps.com"

# ─── GIS Workstation: Legacy Environment ───────────────────────────────────────

# Create Ubuntu Distrobox for legacy GIS workflows with pinned dependencies
[group('GIS Workstation')]
install-legacy-env:
    #!/usr/bin/bash
    set -euo pipefail
    echo "=== Creating Legacy GIS Environment (Ubuntu Distrobox) ==="
    echo ""
    echo "Select Ubuntu version:"
    echo "  1) 22.04 LTS (Jammy) — for workflows with pinned legacy dependencies"
    echo "  2) 24.04 LTS (Noble) — previous LTS, wide package support"
    echo "  3) 26.04 LTS (Raccoon) — current LTS, recommended"
    echo ""
    read -rp "Version [1-3, default: 3]: " sel
    sel="${sel:-3}"

    declare -A version_map=(
        [1]="22.04"
        [2]="24.04"
        [3]="26.04"
    )

    ubuntu_version="${version_map[$sel]:-26.04}"
    echo ""
    echo "Creating Ubuntu ${ubuntu_version} environment..."

    distrobox create --name "gis-legacy-${ubuntu_version}" --image "ubuntu:${ubuntu_version}"
    distrobox enter "gis-legacy-${ubuntu_version}" -- bash -c "
        sudo apt-get update -qq &&
        sudo apt-get install -y \
            python3-gdal python3-pip \
            libgdal-dev libproj-dev \
            libgeos-dev \
            python3-venv \
            unzip curl &&
        python3 -m venv /opt/gis-env &&
        /opt/gis-env/bin/pip install --upgrade pip &&
        /opt/gis-env/bin/pip install \
            geopandas fiona rasterio pyproj \
            pyshp shapely pandas numpy \
            matplotlib pyogrio whitebox
    "
    just _mark-installed "legacy-env-${ubuntu_version}"
    echo ""
    echo "Legacy environment ready."
    echo "  Enter:    distrobox enter gis-legacy-${ubuntu_version}"
    echo "  Activate: source /opt/gis-env/bin/activate"

# ─── GIS Workstation: System Tools ──────────────────────────────────────────────

# Install virtualization stack (QEMU, libvirt, Cockpit)
[group('GIS Workstation')]
install-virtualization:
    #!/usr/bin/bash
    set -euo pipefail
    echo "=== Installing Virtualization Stack ==="
    sudo rpm-ostree install --idempotent --apply-live \
        qemu qemu-img qemu-system-x86-core qemu-char-spice \
        qemu-device-display-virtio-gpu qemu-device-display-virtio-vga \
        qemu-device-usb-redirect qemu-user-binfmt qemu-user-static \
        libvirt libvirt-nss virt-manager virt-viewer virt-v2v \
        edk2-ovmf \
        cockpit-bridge cockpit-machines cockpit-networkmanager \
        cockpit-ostree cockpit-podman cockpit-selinux cockpit-storaged cockpit-system
    sudo systemctl enable --now libvirtd
    echo ""
    echo "Virtualization stack installed."
    echo "  Cockpit:  https://localhost:9090"
    echo "  libvirt:  sudo virsh list --all"

# Install GPU compute stacks (AMD ROCm + Intel compute runtime)
[group('GIS Workstation')]
install-gpu-compute:
    #!/usr/bin/bash
    set -euo pipefail
    echo "=== Installing GPU Compute Stacks ==="
    sudo rpm-ostree install --idempotent --apply-live \
        rocm-hip rocm-opencl rocm-smi \
        rocm-comgr rocm-llvm rocm-clang \
        rocm-runtime rocminfo \
        hip-rocclr hip-devel \
        rocblas rocsparse rocrand rocprim miopen-hip miopen-opencl \
        intel-compute-runtime intel-igc intel-opencl \
        level-zero level-zero-gpu
    echo ""
    echo "GPU compute stacks installed."
    echo "  AMD:   rocminfo | hipconfig"
    echo "  Intel: clinfo | zeinfo"

# Install printing stack (CUPS, HPLIP, SANE)
[group('GIS Workstation')]
install-printing:
    #!/usr/bin/bash
    set -euo pipefail
    echo "=== Installing Printing Stack ==="
    sudo rpm-ostree install --idempotent --apply-live \
        cups cups-filters cups-pdf \
        hplip hplip-common hplip-libs \
        gutenprint gutenprint-libs gutenprint-libs-ui \
        sane-backends sane-backends-drivers-scanners \
        simple-scan
    sudo systemctl enable --now cups
    echo ""
    echo "Printing stack installed."

# Install Yubikey tools
[group('GIS Workstation')]
install-yubikey:
    #!/usr/bin/bash
    set -euo pipefail
    echo "=== Installing Yubikey Tools ==="
    sudo rpm-ostree install --idempotent --apply-live \
        yubikey-manager yubikey-personalization \
        libyubikey ykclient ykpers \
        pam_yubico
    echo ""
    echo "Yubikey tools installed."

# Install additional shells (zsh, fish, oh-my-zsh, starship)
[group('GIS Workstation')]
install-shells:
    #!/usr/bin/bash
    set -euo pipefail
    echo "=== Installing Shells ==="
    sudo rpm-ostree install --idempotent --apply-live \
        zsh fish \
        fzf zsh-autosuggestions zsh-syntax-highlighting
    echo ""
    echo "Shells installed.  Run: chsh -s /bin/zsh (or /bin/fish)"

# Install non-essential fonts
[group('GIS Workstation')]
install-fonts:
    #!/usr/bin/bash
    set -euo pipefail
    echo "=== Installing Fonts ==="
    sudo rpm-ostree install --idempotent --apply-live \
        google-noto-sans-fonts google-noto-serif-fonts \
        google-noto-sans-mono-fonts google-noto-sans-cjk-fonts \
        google-droid-sans-fonts google-droid-serif-fonts \
        google-droid-sans-mono-fonts \
        jetbrains-mono-fonts fira-code-fonts \
        powerline-fonts
    echo ""
    echo "Fonts installed."

# ─── GIS Workstation: Workflow Bundles ─────────────────────────────────────────

# Cartographer: GRASS + Jupyter (SAGA is in the base image)
[group('GIS Workstation')]
install-bundle-carto:
    just install-jupyter
    @echo "Cartographer bundle complete."

# Remote Sensing: OTB + GRASS + PROJ grids + Jupyter
[group('GIS Workstation')]
install-bundle-rs:
    just install-otb
    just install-proj-grids
    just install-jupyter
    @echo "Remote Sensing bundle complete."

# LiDAR: PROJ grids + WhiteboxTools + CloudCompare
[group('GIS Workstation')]
install-bundle-lidar:
    just install-proj-grids
    just install-whitebox
    just install-cloudcompare
    @echo "LiDAR bundle complete."

# GeoAI: GPU ML stack + Jupyter
[group('GIS Workstation')]
install-bundle-geoai:
    just install-gpu-ml
    just install-jupyter
    @echo "GeoAI bundle complete."

# Web GIS: PostGIS + GeoServer + MapProxy
[group('GIS Workstation')]
install-bundle-webgis:
    just install-postgis
    just install-geoserver
    just install-mapproxy
    @echo "Web GIS bundle complete."
    @echo "  Run 'just setup-postgis-db' after reboot to initialise the database."

# Field: GPS daemon already in base image; installs fieldwork extras
[group('GIS Workstation')]
install-bundle-field:
    just install-fieldwork
    @echo "Field bundle complete."

# ─── GIS Workstation: Maintenance ──────────────────────────────────────────────

# Update all installed recipes
# Host package updates (GRASS, OTB, PostGIS) come from rebasing to a new image.
# Only external tools and venvs are updated in-place here.
[group('GIS Workstation')]
update-all:
    #!/usr/bin/bash
    STATE_DIR="${HOME}/.config/geonix"
    echo "=== Updating Geonix recipes ==="
    [ -f "${STATE_DIR}/whitebox.installed" ] && just update-whitebox || true
    [ -f "${STATE_DIR}/fieldwork.installed" ] && just update-qfield || true
    [ -f "${STATE_DIR}/qgis-plugins.installed" ] && just update-qgis-plugins || true
    flatpak update -y 2>/dev/null || true
    for venv in mapproxy-env jupyter-env geoai-env; do
        VENV="${HOME}/.local/share/geonix/${venv}"
        if [ -d "$VENV" ]; then
            "$VENV/bin/pip" install --upgrade pip -q
            "$VENV/bin/pip" list --outdated 2>/dev/null \
                | awk 'NR>2{print $1}' \
                | xargs -r "$VENV/bin/pip" install --upgrade -q || true
        fi
    done
    echo ""
    echo "Recipe update complete."
    echo "  Host package updates (GRASS, OTB, PostGIS): rebase to latest geonix image."
    echo "  GeoAI Distrobox: distrobox enter geoai -- pip3 install --upgrade torchgeo"
