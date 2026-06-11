#!/usr/bin/bash
echo "--> Executing dedicated branding.sh pipeline..."

# --- 1. CORE VARIABLES ---
IMAGE_VENDOR="${IMAGE_REGISTRY##*/}"   # Derive from build arg dynamically
IMAGE_LIKE="centos rhel fedora"
HOME_URL="https://github.com/a2rk313/geonix"
SUPPORT_URL="https://github.com/a2rk313/geonix/issues"
IMAGE_PRETTY_NAME="Geonix"

# --- 2. OS-RELEASE FORGE (Idempotent Injection) ---
OS_RELEASE="/usr/lib/os-release"

# We define a function to guarantee the variable is written,
# even if the upstream vendor deleted it from their base image.
inject_os_release() {
    local key=$1
    local value=$2
    if grep -q "^${key}=" "$OS_RELEASE"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$OS_RELEASE"
    else
        echo "${key}=${value}" >> "$OS_RELEASE"
    fi
}

# Apply the injections
inject_os_release "VARIANT_ID" "geonix"
inject_os_release "PRETTY_NAME" "\"${IMAGE_PRETTY_NAME}\""
inject_os_release "NAME" "\"${IMAGE_PRETTY_NAME}\""
inject_os_release "ID" "${IMAGE_NAME:-geonix}"
inject_os_release "ID_LIKE" "\"${IMAGE_LIKE}\""
inject_os_release "HOME_URL" "\"${HOME_URL}\""
inject_os_release "SUPPORT_URL" "\"${SUPPORT_URL}\""
inject_os_release "DEFAULT_HOSTNAME" "\"geonix\""

# Purge Red Hat telemetry/support strings
sed -i "/^REDHAT_BUGZILLA_PRODUCT=/d; /^REDHAT_BUGZILLA_PRODUCT_VERSION=/d; /^REDHAT_SUPPORT_PRODUCT=/d; /^REDHAT_SUPPORT_PRODUCT_VERSION=/d" "$OS_RELEASE"

# --- 3. JSON DATABASE MUTATION ---
INFO_FILE="/usr/share/ublue-os/image-info.json"

if [[ -f "$INFO_FILE" ]]; then
    echo "--> Mutating upstream image-info.json..."

    # We use jq to safely overwrite keys while preserving base-image properties
    jq \
        --arg name   "${IMAGE_NAME:-geonix}" \
        --arg vendor "$IMAGE_VENDOR" \
        --arg tag    "${DEFAULT_TAG:-latest}" \
        --arg ref    "ostree-image-signed:docker://${IMAGE_REGISTRY:-ghcr.io/a2rk313}/${IMAGE_NAME:-geonix}" \
        '. | .["image-name"]=$name | .["image-vendor"]=$vendor | .["image-tag"]=$tag | .["image-ref"]=$ref' \
        "$INFO_FILE" > /tmp/image-info.json \
    && mv /tmp/image-info.json "$INFO_FILE"
else
    echo "--> WARNING: $INFO_FILE not found. Skipping JSON mutation."
fi

# --- 4. MOTD TEMPLATE ---
cat > /usr/share/ublue-os/motd/template.md << 'EOF'
# 🌍 Welcome to Geonix
**GIS and Remote Sensing out of the box.**

🚀 `${MOTD_IMAGE_NAME}:${MOTD_IMAGE_TAG}`

| Command | Description |
|---------|-------------|
| `gj --list` | Show all available commands |
| `gj status` | Show installed GIS recipes |
| `gj install-bundle-rs` | Install Remote Sensing stack |
| `gj install-bundle-lidar` | Install LiDAR stack |
| `gj install-qgis-plugins` | Install QGIS plugins |
| `qgis` | Launch QGIS Desktop |

${MOTD_TIP}

- [Geonix Repository](https://github.com/a2rk313/geonix)
- [Report an Issue](https://github.com/a2rk313/geonix/issues)
EOF
echo "--> MOTD template written"

# --- 5. PLYMOUTH ---
PLYMOUTH_THEME="/usr/share/plymouth/themes/spinner"
if [[ -d "$PLYMOUTH_THEME" ]]; then
    cp /build-assets/logo/logo_small_128.png "${PLYMOUTH_THEME}/watermark.png"
    cp /build-assets/logo/logo_small_128.png "${PLYMOUTH_THEME}/bgrt-fallback.png"
    echo "--> Plymouth branding applied"
else
    echo "--> WARNING: Plymouth spinner theme not found, skipping"
fi
