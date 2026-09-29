#!/usr/bin/bash
# Fail the build if the shipped initramfs lacks the geonix-branded plymouth
# theme or the ostree composefs binding config. geonix regenerates the
# initramfs after branding; a regen that strips either of these silently
# degrades the boot splash AND the base's integrity mode.
# composefs "signed" mode is intentionally out of scope — this gate only
# guarantees the verity binding survives.
# Usage: verified-initramfs.sh /usr/lib/modules/<kver>/initramfs.img
set -euo pipefail
IMG="${1:?usage: verified-initramfs.sh <initramfs.img>}"
KVER="$(basename "$(dirname "$IMG")")"
for needle in 'spinner/bgrt-fallback\.png' 'spinner/silverblue-logo\.png' 'ostree/prepare-root\.conf'; do
  if ! lsinitrd "${IMG}" | grep -qE "${needle}"; then
    echo "ERROR: initramfs ${KVER} missing ${needle} — regen did not carry branding / ostree bindings" >&2
    exit 1
  fi
done
echo "OK: initramfs ${KVER} carries branded theme + prepare-root.conf"
