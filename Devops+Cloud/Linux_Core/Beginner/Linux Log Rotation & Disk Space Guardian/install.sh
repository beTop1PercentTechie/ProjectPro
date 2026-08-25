#!/usr/bin/env bash
# install.sh - Prepares Guardian for use in place: creates the data/logs
# directories, sets executable permissions, and optionally symlinks
# bin/diskguardian onto PATH.
#
# Usage: sudo ./install.sh [--symlink]

set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
readonly SYMLINK_TARGET="/usr/local/bin/diskguardian"

[[ "$EUID" -eq 0 ]] || { echo "Run this installer with sudo/root."; exit 1; }

echo "Installing Guardian from: $SCRIPT_DIR"

mkdir -p "$SCRIPT_DIR/data" "$SCRIPT_DIR/logs" "$SCRIPT_DIR/logs/reports"

find "$SCRIPT_DIR" -maxdepth 1 -name '*.sh' -exec chmod +x {} \;
find "$SCRIPT_DIR/lib" "$SCRIPT_DIR/alerts" "$SCRIPT_DIR/cron" "$SCRIPT_DIR/tests" \
    -name '*.sh' -exec chmod +x {} \;
chmod +x "$SCRIPT_DIR/bin/diskguardian"

echo "Set executable permissions on all Guardian scripts."

if [[ "${1:-}" == "--symlink" ]]; then
    ln -sf "$SCRIPT_DIR/bin/diskguardian" "$SYMLINK_TARGET"
    echo "Symlinked $SYMLINK_TARGET -> $SCRIPT_DIR/bin/diskguardian"
    echo "You can now run 'diskguardian --help' from anywhere."
fi

cat <<DONE

Installation complete.

Next steps:
  1. Review config/guardian.conf and config/rotation_policy.conf
  2. Do a dry run first (no files touched):
       sudo $SCRIPT_DIR/guardian.sh --full --dry-run
  3. Run for real:
       sudo $SCRIPT_DIR/guardian.sh --monitor
       sudo $SCRIPT_DIR/guardian.sh --full
  4. Schedule the recommended cron cadence:
       sudo $SCRIPT_DIR/cron/guardian_scheduler.sh install "*/5 * * * *" "0 3 * * *"

See README.md for full documentation.
DONE
