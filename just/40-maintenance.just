# ─── Maintenance: Updates ──────────────────────────────────────────────────────

# Update all installed recipes
[group('Maintenance')]
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

# Update WhiteboxTools
[group('Maintenance')]
update-whitebox:
    #!/usr/bin/bash
    CURRENT=$(whitebox_tools --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
    LATEST=$(curl -s https://api.github.com/repos/jblindsay/whitebox-tools/releases/latest \
        | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/')
    echo "Installed: ${CURRENT:-unknown}   Latest: ${LATEST}"
    [[ "$CURRENT" == "$LATEST" ]] && echo "Already up to date." || just install-whitebox

# Update QGIS plugins
[group('Maintenance')]
update-qgis-plugins:
    #!/usr/bin/bash
    set -euo pipefail
    PLUGIN_DIR="${HOME}/.local/share/QGIS/QGIS3/profiles/default/python/plugins"
    cd "$PLUGIN_DIR"
    pip3 install --user --break-system-packages --upgrade qgis-plugin-manager
    qgis-plugin-manager update
    qgis-plugin-manager upgrade
    echo "QGIS plugins updated."

# Clean build artifacts
[group('Maintenance')]
clean:
    #!/usr/bin/bash
    rm -rf output/ mkosi.cache/
    echo "Build artifacts cleaned."
