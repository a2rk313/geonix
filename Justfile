export image_name := env("IMAGE_NAME", "geonix")
export default_tag := env("DEFAULT_TAG", "latest")
export bib_image := env("BIB_IMAGE", "quay.io/centos-bootc/bootc-image-builder:latest")

alias build-vm := build-qcow2
alias rebuild-vm := rebuild-qcow2
alias run-vm := run-vm-qcow2

[private]
default:
    @just --list

# ─── Just Tooling ──────────────────────────────────────────────────────────────

# Check Just syntax across all Justfiles in the repo
[group('Just')]
check:
    #!/usr/bin/bash
    find . -type f -name "*.just" | while read -r file; do
        echo "Checking syntax: $file"
        just --unstable --fmt --check -f $file
    done
    echo "Checking syntax: Justfile"
    just --unstable --fmt --check -f Justfile

# Fix Just syntax across all Justfiles in the repo
[group('Just')]
fix:
    #!/usr/bin/bash
    find . -type f -name "*.just" | while read -r file; do
        echo "Fixing syntax: $file"
        just --unstable --fmt -f $file
    done
    echo "Fixing syntax: Justfile"
    just --unstable --fmt -f Justfile || { exit 1; }

# ─── Utility ───────────────────────────────────────────────────────────────────

# Clean build artifacts
[group('Utility')]
clean:
    #!/usr/bin/bash
    set -eoux pipefail
    touch _build
    find *_build* -exec rm -rf {} \;
    rm -f previous.manifest.json
    rm -f changelog.md
    rm -f output.env
    rm -f output/

[group('Utility')]
[private]
sudo-clean:
    just sudoif just clean

# sudoif: run a command as root, using sudo if available, or failing cleanly
[group('Utility')]
[private]
sudoif command *args:
    #!/usr/bin/bash
    function sudoif(){
        if [[ "${UID}" -eq 0 ]]; then
            "$@"
        elif [[ "$(command -v sudo)" && -n "${SSH_ASKPASS:-}" ]] && [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
            /usr/bin/sudo --askpass "$@" || exit 1
        elif [[ "$(command -v sudo)" ]]; then
            /usr/bin/sudo "$@" || exit 1
        else
            exit 1
        fi
    }
    sudoif {{ command }} {{ args }}

# ─── Build Image ───────────────────────────────────────────────────────────────

# Build a container image
# Usage: just build [target_image] [tag] [base_image]
# Example: just build geonix-plasma latest ghcr.io/ublue-os/aurora:latest
[group('Build Image')]
build $target_image=image_name $tag=default_tag $base_image="ghcr.io/ublue-os/bluefin:latest":
    #!/usr/bin/env bash
    set -euo pipefail

    BUILD_ARGS=()
    BUILD_ARGS+=("--build-arg" "BASE_IMAGE=${base_image}")

    # Include git SHA if working tree is clean
    if [[ -z "$(git status -s)" ]]; then
        BUILD_ARGS+=("--build-arg" "SHA_HEAD_SHORT=$(git rev-parse --short HEAD)")
    fi

    echo "Building ${target_image}:${tag} from ${base_image}"
    podman build \
        "${BUILD_ARGS[@]}" \
        --pull=newer \
        --tag "${target_image}:${tag}" \
        .

# Build the Aurora (KDE) variant
# Usage: just build-aurora [tag]
[group('Build Image')]
build-aurora $tag=default_tag:
    just build geonix-plasma $tag ghcr.io/ublue-os/aurora:latest

# Build the Bluefin (GNOME) variant
# Usage: just build-bluefin [tag]
[group('Build Image')]
build-bluefin $tag=default_tag:
    just build geonix-gnome $tag ghcr.io/ublue-os/bluefin:latest

# Build both Aurora and Bluefin variants sequentially
[group('Build Image')]
build-all $tag=default_tag:
    just build-aurora $tag
    just build-bluefin $tag

# ─── Internal: Image Loading ───────────────────────────────────────────────────

# Load a user podman image into rootful podman (required for BIB)
[private]
_rootful_load_image $target_image=image_name $tag=default_tag:
    #!/usr/bin/bash
    set -eoux pipefail

    # Already root — nothing to do
    if [[ -n "${SUDO_USER:-}" || "${UID}" -eq "0" ]]; then
        echo "Already root or running under sudo, no need to load image from user podman."
        exit 0
    fi

    set +e
    resolved_tag=$(podman inspect -t image "${target_image}:${tag}" | jq -r '.[].RepoTags.[0]')
    return_code=$?
    set -e

    USER_IMG_ID=$(podman images --filter reference="${target_image}:${tag}" --format "{{ '{{.ID}}' }}")

    if [[ $return_code -eq 0 ]]; then
        ID=$(just sudoif podman images --filter reference="${target_image}:${tag}" --format "{{ '{{.ID}}' }}")
        if [[ "$ID" != "$USER_IMG_ID" ]]; then
            COPYTMP=$(mktemp -p "${PWD}" -d -t _build_podman_scp.XXXXXXXXXX)
            just sudoif TMPDIR=${COPYTMP} podman image scp ${UID}@localhost::"${target_image}:${tag}" root@localhost::"${target_image}:${tag}"
            rm -rf "${COPYTMP}"
        fi
    else
        just sudoif podman pull "${target_image}:${tag}"
    fi

# ─── Internal: Bootc Image Builder ────────────────────────────────────────────

# Run BIB to produce a disk image from a container image
# Parameters: target_image, tag, type (qcow2/raw/anaconda-iso), config toml path
[private]
_build-bib $target_image $tag $type $config: (_rootful_load_image target_image tag)
    #!/usr/bin/env bash
    set -euo pipefail

    args="--type ${type} "
    args+="--use-librepo=True "

    BUILDTMP=$(mktemp -p "${PWD}" -d -t _build-bib.XXXXXXXXXX)

    sudo podman run \
        --rm \
        -it \
        --privileged \
        --pull=newer \
        --net=host \
        --security-opt label=type:unconfined_t \
        -v "$(pwd)/${config}:/config.toml:ro" \
        -v "$BUILDTMP:/output" \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        "${bib_image}" \
        ${args} \
        "${target_image}:${tag}"

    mkdir -p output
    sudo mv -f "$BUILDTMP"/* output/
    sudo rmdir "$BUILDTMP"
    sudo chown -R "$USER:$USER" output/

# Build container image then produce a disk image
[private]
_rebuild-bib $target_image $tag $type $config: (build target_image tag) && (_build-bib target_image tag type config)

# ─── Build Virtual Machine Image ──────────────────────────────────────────────

# Build a QCOW2 virtual machine image (Bluefin/GNOME)
[group('Build Virtual Machine Image')]
build-qcow2 $target_image=("localhost/geonix-gnome") $tag=default_tag: && (_build-bib target_image tag "qcow2" "disk_config/disk.toml")

# Build a RAW virtual machine image (Bluefin/GNOME)
[group('Build Virtual Machine Image')]
build-raw $target_image=("localhost/geonix-gnome") $tag=default_tag: && (_build-bib target_image tag "raw" "disk_config/disk.toml")

# Build a KDE (Aurora) installer ISO
[group('Build Virtual Machine Image')]
build-iso-kde $target_image=("localhost/geonix-plasma") $tag=default_tag: && (_build-bib target_image tag "anaconda-iso" "disk_config/iso-kde.toml")

# Build a GNOME (Bluefin) installer ISO
[group('Build Virtual Machine Image')]
build-iso-gnome $target_image=("localhost/geonix-gnome") $tag=default_tag: && (_build-bib target_image tag "anaconda-iso" "disk_config/iso-gnome.toml")

# Rebuild QCOW2 (rebuilds container image first)
[group('Build Virtual Machine Image')]
rebuild-qcow2 $target_image=("localhost/geonix-gnome") $tag=default_tag: && (_rebuild-bib target_image tag "qcow2" "disk_config/disk.toml")

# Rebuild RAW (rebuilds container image first)
[group('Build Virtual Machine Image')]
rebuild-raw $target_image=("localhost/geonix-gnome") $tag=default_tag: && (_rebuild-bib target_image tag "raw" "disk_config/disk.toml")

# Rebuild KDE ISO (rebuilds container image first)
[group('Build Virtual Machine Image')]
rebuild-iso-kde $target_image=("localhost/geonix-plasma") $tag=default_tag: && (_rebuild-bib target_image tag "anaconda-iso" "disk_config/iso-kde.toml")

# Rebuild GNOME ISO (rebuilds container image first)
[group('Build Virtual Machine Image')]
rebuild-iso-gnome $target_image=("localhost/geonix-gnome") $tag=default_tag: && (_rebuild-bib target_image tag "anaconda-iso" "disk_config/iso-gnome.toml")

# ─── Run Virtual Machine ───────────────────────────────────────────────────────

# Internal: run a VM from a disk image using qemux/qemu container
[private]
_run-vm $target_image $tag $type $config:
    #!/usr/bin/bash
    set -eoux pipefail

    image_file="output/${type}/disk.${type}"
    if [[ $type == anaconda-iso ]]; then
        image_file="output/bootiso/install.iso"
    fi

    if [[ ! -f "${image_file}" ]]; then
        just "build-${type}" "$target_image" "$tag"
    fi

    # Find an available port starting at 8006
    port=8006
    while grep -q ":${port}" <<< "$(ss -tunalp)"; do
        port=$(( port + 1 ))
    done
    echo "Using port: ${port}"
    echo "Connect to: http://localhost:${port}"

    run_args=()
    run_args+=(--rm --privileged)
    run_args+=(--pull=newer)
    run_args+=(--publish "127.0.0.1:${port}:8006")
    run_args+=(--env "CPU_CORES=4")
    run_args+=(--env "RAM_SIZE=8G")
    run_args+=(--env "DISK_SIZE=64G")
    run_args+=(--env "TPM=Y")
    run_args+=(--env "GPU=Y")
    run_args+=(--device=/dev/kvm)
    run_args+=(--volume "${PWD}/${image_file}":"/boot.${type}")
    run_args+=(docker.io/qemux/qemu)

    (sleep 30 && xdg-open "http://localhost:${port}") &
    podman run "${run_args[@]}"

# Run a VM from a QCOW2 image
[group('Run Virtual Machine')]
run-vm-qcow2 $target_image=("localhost/geonix-gnome") $tag=default_tag: && (_run-vm target_image tag "qcow2" "disk_config/disk.toml")

# Run a VM from a RAW image
[group('Run Virtual Machine')]
run-vm-raw $target_image=("localhost/geonix-gnome") $tag=default_tag: && (_run-vm target_image tag "raw" "disk_config/disk.toml")

# Run a KDE ISO installer in a VM
[group('Run Virtual Machine')]
run-vm-iso-kde $target_image=("localhost/geonix-plasma") $tag=default_tag: && (_run-vm target_image tag "anaconda-iso" "disk_config/iso-kde.toml")

# Run a GNOME ISO installer in a VM
[group('Run Virtual Machine')]
run-vm-iso-gnome $target_image=("localhost/geonix-gnome") $tag=default_tag: && (_run-vm target_image tag "anaconda-iso" "disk_config/iso-gnome.toml")

# Run a VM using systemd-vmspawn (faster than qemux for quick testing)
[group('Run Virtual Machine')]
spawn-vm rebuild="0" type="qcow2" ram="6G":
    #!/usr/bin/env bash
    set -euo pipefail

    [[ "{{ rebuild }}" -eq 1 ]] && echo "Rebuilding image..." && just build-qcow2

    systemd-vmspawn \
        -M "geonix" \
        --console=gui \
        --cpus=2 \
        --ram="$(echo "{{ ram }}" | /usr/bin/numfmt --from=iec)" \
        --network-user-mode \
        --vsock=false \
        --pass-ssh-key=false \
        -i ./output/**/*."{{ type }}"

# ─── Linting & Formatting ──────────────────────────────────────────────────────

# Run shellcheck on all shell scripts
[group('Lint & Format')]
lint:
    #!/usr/bin/env bash
    set -eoux pipefail
    if ! command -v shellcheck &> /dev/null; then
        echo "shellcheck not found. Install it: sudo dnf install shellcheck"
        exit 1
    fi
    /usr/bin/find . -iname "*.sh" -type f -exec shellcheck "{}" ';'

# Run shfmt on all shell scripts
[group('Lint & Format')]
format:
    #!/usr/bin/env bash
    set -eoux pipefail
    if ! command -v shfmt &> /dev/null; then
        echo "shfmt not found. Install it: sudo dnf install shfmt"
        exit 1
    fi
    /usr/bin/find . -iname "*.sh" -type f -exec shfmt --write "{}" ';'
