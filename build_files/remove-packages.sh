#!/usr/bin/env bash
set -euo pipefail

# Packages to remove from base image to save space.
# Each package is verified in the base image's dnf5 database before removal.
# VM stack, GPU compute, printing, shells, fonts stripped at build time;
# users re-install via `just install-*` recipes after first boot.
# VSCode, podman-compose, switcheroo-control stay in base.

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

    # AMD GPU compute (ROCm) — users get via `just install-gpu-compute`
    rocm-hip
    rocm-opencl
    rocm-smi
    rocm-comgr
    rocm-llvm
    rocm-clang
    rocm-runtime
    rocminfo
    hip-rocclr
    hip-devel
    rocblas
    rocsparse
    rocrand
    rocprim
    miopen-hip
    miopen-opencl

    # Intel GPU compute — users get via `just install-gpu-compute`
    intel-compute-runtime
    intel-igc
    intel-opencl
    level-zero
    level-zero-gpu

    # Printing — users get via `just install-printing`
    cups
    cups-filters
    cups-pdf
    hplip
    hplip-common
    hplip-libs
    gutenprint
    gutenprint-libs
    gutenprint-libs-ui
    sane-backends
    sane-backends-drivers-scanners
    simple-scan

    # Yubikey — users get via `just install-yubikey`
    yubikey-manager
    yubikey-personalization
    libyubikey
    ykclient
    ykpers
    pam_yubico

    # Shells — users get via `just install-shells`
    zsh
    fish
    oh-my-zsh
    starship
    fzf
    zsh-autosuggestions
    zsh-syntax-highlighting

    # Fonts (non-essential) — users get via `just install-fonts`
    google-noto-sans-fonts
    google-noto-serif-fonts
    google-noto-sans-mono-fonts
    google-noto-sans-cjk-fonts
    google-noto-sans-italic-fonts
    google-noto-serif-italic-fonts
    google-noto-sans-mono-fonts
    google-droid-sans-fonts
    google-droid-serif-fonts
    google-droid-sans-mono-fonts
    jetbrains-mono-fonts
    fira-code-fonts
    powerline-fonts
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
