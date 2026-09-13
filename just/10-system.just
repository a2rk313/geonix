# ─── System: ostree Management ────────────────────────────────────────────────

# Show current ostree deployment status
[group('System')]
status:
    #!/usr/bin/bash
    echo "=== Geonix System Status ==="
    ostree admin status

# Check for available updates
[group('System')]
check-update:
    #!/usr/bin/bash
    echo "=== Checking for updates ==="
    ostree admin upgrade --check

# Apply ostree update
[group('System')]
update:
    #!/usr/bin/bash
    echo "=== Updating system ==="
    sudo ostree admin upgrade
    echo ""
    echo "Update downloaded. Reboot to activate:"
    echo "  sudo reboot"

# Rollback to previous deployment
[group('System')]
rollback:
    #!/usr/bin/bash
    echo "=== Rolling back to previous deployment ==="
    sudo ostree admin rollback
    echo ""
    echo "Rollback scheduled. Reboot to activate:"
    echo "  sudo reboot"

# Add ostree remote
[group('System')]
add-remote url:
    #!/usr/bin/bash
    echo "=== Adding ostree remote ==="
    sudo ostree remote add --if-not-exists geonix {{ url }}
    echo "Remote added: {{ url }}"

# List ostree remotes
[group('System')]
list-remotes:
    #!/usr/bin/bash
    echo "=== ostree remotes ==="
    ostree remote list
