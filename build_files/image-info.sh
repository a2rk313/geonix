#!/usr/bin/bash
set -ouex pipefail

echo "Executing image-info and branding pipeline..."

# --- 1. CORE VARIABLES ---
IMAGE_VENDOR="${IMAGE_REGISTRY##*/}"
IMAGE_LIKE="aurora ublue fedora bluefin image-based immutable gis rs workstation"
HOME_URL="https://github.com/a2rk313/geonix"
SUPPORT_URL="https://github.com/a2rk313/geonix/issues"
IMAGE_PRETTY_NAME="Geonix"

# --- 2. OS-RELEASE ---
OS_RELEASE="/usr/lib/os-release"

inject_os_release() {
    local key=$1
    local value=$2
    if grep -q "^${key}=" "$OS_RELEASE"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$OS_RELEASE"
    else
        echo "${key}=${value}" >> "$OS_RELEASE"
    fi
}

inject_os_release "VARIANT_ID"       "geonix"
inject_os_release "PRETTY_NAME"      "\"${IMAGE_PRETTY_NAME}\""
inject_os_release "NAME"             "\"${IMAGE_PRETTY_NAME}\""
inject_os_release "ID"               "${IMAGE_NAME:-geonix}"
inject_os_release "ID_LIKE"          "\"${IMAGE_LIKE}\""
inject_os_release "HOME_URL"         "\"${HOME_URL}\""
inject_os_release "SUPPORT_URL"      "\"${SUPPORT_URL}\""
inject_os_release "DEFAULT_HOSTNAME" "\"geonix\""

sed -i "/^REDHAT_BUGZILLA_PRODUCT=/d; /^REDHAT_BUGZILLA_PRODUCT_VERSION=/d; /^REDHAT_SUPPORT_PRODUCT=/d; /^REDHAT_SUPPORT_PRODUCT_VERSION=/d" "$OS_RELEASE"

# --- 3. IMAGE INFO JSON ---
INFO_FILE="/usr/share/ublue-os/image-info.json"
if [[ -f "$INFO_FILE" ]]; then
    echo "Mutating upstream image-info.json..."
    jq \
        --arg name   "${IMAGE_NAME:-geonix}" \
        --arg vendor "$IMAGE_VENDOR" \
        --arg tag    "${DEFAULT_TAG:-latest}" \
        --arg ref    "ostree-image-signed:docker://${IMAGE_REGISTRY:-ghcr.io/a2rk313}/${IMAGE_NAME:-geonix}" \
        '. | .["image-name"]=$name | .["image-vendor"]=$vendor | .["image-tag"]=$tag | .["image-ref"]=$ref' \
        "$INFO_FILE" > /tmp/image-info.json \
    && mv /tmp/image-info.json "$INFO_FILE"
else
    echo "WARNING: $INFO_FILE not found. Skipping JSON mutation."
fi

# --- 4. GJ SYMLINK ---
if [[ -f /usr/bin/ujust && ! -e /usr/bin/gj ]]; then
    ln -s /usr/bin/ujust /usr/bin/gj
    echo "gj symlink created"
fi

# --- 5. ENTRY JUSTFILE ---
cat > /usr/share/ublue-os/just/00-entry.just << 'EOF'
set allow-duplicate-recipes := true
set ignore-comments := true

_default:
    #!/usr/bin/bash
    echo "🌍 Geonix — GIS and Remote Sensing out of the box"
    echo "Docs: https://github.com/a2rk313/geonix"
    echo ""
    gj --list --list-heading $'Available commands:\n' --list-prefix $'  - '

import "/usr/share/ublue-os/just/apps.just"
import "/usr/share/ublue-os/just/changelog.just"
import "/usr/share/ublue-os/just/default.just"
import "/usr/share/ublue-os/just/shared.just"
import "/usr/share/ublue-os/just/system.just"
import "/usr/share/ublue-os/just/update.just"
import? "/usr/share/ublue-os/just/60-custom.just"
EOF
echo "Entry justfile written"
