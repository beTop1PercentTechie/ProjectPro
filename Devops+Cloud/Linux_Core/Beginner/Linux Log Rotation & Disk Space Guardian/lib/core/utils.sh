#!/usr/bin/env bash
# utils.sh - Shared helper functions used by the main script and modules.

# require_root: abort unless running as root (needed to read/rotate logs
# owned by other users/services and to scan the full filesystem).
require_root() {
    if [[ "$EUID" -ne 0 ]]; then
        echo "Guardian must be run as root (or with sudo) for full disk/log access." >&2
        exit 1
    fi
}

# command_exists <name> - true if a binary is on PATH.
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# timestamp_now - filesystem-safe timestamp, e.g. 2026-07-30_14-05-02
timestamp_now() {
    date '+%Y-%m-%d_%H-%M-%S'
}

# human_date - readable date for report headers.
human_date() {
    date '+%Y-%m-%d %H:%M:%S %Z'
}

# epoch_now - current time in seconds since epoch.
epoch_now() {
    date '+%s'
}

# ensure_dir <path> - create a directory tree if missing.
ensure_dir() {
    [[ -d "$1" ]] || mkdir -p "$1"
}

# trim <string> - strip leading/trailing whitespace.
trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# to_lower <string>
to_lower() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

# kb_to_human <kilobytes> - render KB as a human-friendly KB/MB/GB string.
kb_to_human() {
    local kb="$1"
    awk -v k="$kb" 'BEGIN {
        if (k >= 1073741824) printf "%.2f TB", k/1073741824;
        else if (k >= 1048576) printf "%.2f GB", k/1048576;
        else if (k >= 1024) printf "%.2f MB", k/1024;
        else printf "%d KB", k;
    }'
}

# bytes_to_human <bytes> - render a byte count as a human-friendly string.
bytes_to_human() {
    local bytes="$1"
    awk -v b="$bytes" 'BEGIN {
        if (b >= 1099511627776) printf "%.2f TB", b/1099511627776;
        else if (b >= 1073741824) printf "%.2f GB", b/1073741824;
        else if (b >= 1048576) printf "%.2f MB", b/1048576;
        else if (b >= 1024) printf "%.2f KB", b/1024;
        else printf "%d B", b;
    }'
}

# seconds_to_human <seconds> - render a duration as "Xd Yh Zm".
seconds_to_human() {
    local total="$1"
    awk -v s="$total" 'BEGIN {
        if (s < 0) s = 0;
        d = int(s/86400); s -= d*86400;
        h = int(s/3600);  s -= h*3600;
        m = int(s/60);
        if (d > 0) printf "%dd %dh %dm", d, h, m;
        else if (h > 0) printf "%dh %dm", h, m;
        else printf "%dm", m;
    }'
}
