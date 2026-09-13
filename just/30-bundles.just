# ─── GIS Workstation: Bundle Status ────────────────────────────────────────────

# Show all available bundles
[group('Bundles')]
bundle-list:
    #!/usr/bin/bash
    echo "=== Available Bundles ==="
    echo ""
    echo "  rs         Remote Sensing (OTB + Jupyter)"
    echo "  lidar      LiDAR (WhiteboxTools + CloudCompare)"
    echo "  geoai      GeoAI (Jupyter)"
    echo "  webgis     Web GIS (PostGIS)"
    echo ""
    echo "Install with: gj install-bundle-<name>"
