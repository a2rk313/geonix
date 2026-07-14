#!/usr/bin/env bash
set -euo pipefail

# Packages to remove from base image to save space.
# Each package is verified in the base image's dnf5 database before removal.
# QEMU/libvirt/cockpit stays in base for ISO builds; VM-only users get it
# via `just install-vm` after first boot.
# Podman compose is kept for devcontainer/CI use.

REMOVE=(
    # Docker stack (redundant with podman)
    docker-ce
    docker-ce-cli
    containerd.io
    docker-buildx-plugin
    docker-compose-plugin
    docker-model-plugin

    # Podman add-ons (keep podman itself + podman-compose)
    podman-machine
    podman-tui

    # Cockpit stack
    cockpit-bridge
    cockpit-machines
    cockpit-networkmanager
    cockpit-ostree
    cockpit-podman
    cockpit-selinux
    cockpit-storaged
    cockpit-system

    # Incus/LXC
    incus
    incus-agent
    lxc

    # Profiling / eBPF
    bcc
    bpftop
    bpftrace
    sysprof
    udica

    # Low-priority tools
    iotop
    nicstat
    tiptop
    trace-cmd

    # Misc
    android-tools
    flatpak-builder
    genisoimage
    cryfs
    ydotool
    wtype
)

# Aurora-only packages — only remove if present
AURORA_ONLY=(
    kcli
    bcvk
)

# Check what's actually installed and only remove what exists
REMOVE_INSTALLED=()
for pkg in "${REMOVE[@]}"; do
    if rpm -q "$pkg" &>/dev/null 2>&1; then
        REMOVE_INSTALLED+=("$pkg")
    fi
done

for pkg in "${AURORA_ONLY[@]}"; do
    if rpm -q "$pkg" &>/dev/null 2>&1; then
        REMOVE_INSTALLED+=("$pkg")
    fi
done

if [[ ${#REMOVE_INSTALLED[@]} -gt 0 ]]; then
    echo "Removing: ${REMOVE_INSTALLED[*]}"
    sudo dnf5 remove -y "${REMOVE_INSTALLED[@]}"
else
    echo "Nothing to remove"
fi
