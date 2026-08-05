#!/usr/bin/env bash
# install.sh - Prepares LSAMS for use in place: creates the reports/logs
# directories, sets executable permissions, and optionally symlinks
# bin/lsams onto PATH.
#
# Usage: sudo ./install.sh [--symlink]

set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
readonly SYMLINK_TARGET="/usr/local/bin/lsams"

[[ "$EUID" -eq 0 ]] || { echo "Run this installer with sudo/root."; exit 1; }

echo "Installing LSAMS from: $SCRIPT_DIR"

mkdir -p "$SCRIPT_DIR/reports" "$SCRIPT_DIR/logs"

find "$SCRIPT_DIR" -maxdepth 1 -name '*.sh' -exec chmod +x {} \;
find "$SCRIPT_DIR/lib" "$SCRIPT_DIR/alerts" "$SCRIPT_DIR/cron" "$SCRIPT_DIR/tests" \
    -name '*.sh' -exec chmod +x {} \;
chmod +x "$SCRIPT_DIR/bin/lsams"

echo "Set executable permissions on all LSAMS scripts."

if [[ "${1:-}" == "--symlink" ]]; then
    ln -sf "$SCRIPT_DIR/bin/lsams" "$SYMLINK_TARGET"
    echo "Symlinked $SYMLINK_TARGET -> $SCRIPT_DIR/bin/lsams"
    echo "You can now run 'lsams --help' from anywhere."
fi

cat <<DONE

Installation complete.

Next steps:
  1. Review config/lsams.conf and config/compliance_rules.conf
  2. Run a test audit:   sudo $SCRIPT_DIR/lsams.sh --quick
  3. Schedule periodic audits: sudo $SCRIPT_DIR/cron/lsams_scheduler.sh install "0 3 * * *"

See README.md for full documentation.
DONE
