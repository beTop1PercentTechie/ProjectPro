#!/usr/bin/env bash
# utils.sh - Shared helper functions used by the main script and modules.

# require_root: abort unless running as root (most checks need read access
# to /etc/shadow, sshd_config, journalctl, etc.)
require_root() {
    if [[ "$EUID" -ne 0 ]]; then
        echo "LSAMS must be run as root (or with sudo) for a complete audit." >&2
        exit 1
    fi
}

# command_exists <name> - true if a binary is on PATH.
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# is_service_active <name> - true if a systemd unit is active.
is_service_active() {
    systemctl is-active --quiet "$1" 2>/dev/null
}

# is_service_enabled <name> - true if a systemd unit is enabled at boot.
is_service_enabled() {
    systemctl is-enabled --quiet "$1" 2>/dev/null
}

# timestamp_now - filesystem-safe timestamp, e.g. 2026-07-30_14-05-02
timestamp_now() {
    date '+%Y-%m-%d_%H-%M-%S'
}

# human_date - readable date for report headers.
human_date() {
    date '+%Y-%m-%d %H:%M:%S %Z'
}

# ensure_dir <path> - create a directory tree if missing.
ensure_dir() {
    [[ -d "$1" ]] || mkdir -p "$1"
}

# os_pretty_name - OS description from /etc/os-release, falls back to uname.
os_pretty_name() {
    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        (. /etc/os-release && echo "$PRETTY_NAME")
    else
        uname -srm
    fi
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

# sshd_effective_value <key> - the effective value of an sshd_config
# directive, matching what sshd itself will actually use at runtime.
#
# Modern OpenSSH ships secure-by-default values (e.g. PermitRootLogin
# defaults to 'prohibit-password') even when sshd_config doesn't set them
# explicitly. 'sshd -T' resolves the true effective config including those
# compiled-in defaults; a raw grep of the file only sees explicit lines and
# would misreport an unset-but-secure setting as insecure. Shared by
# lib/modules/02_ssh_audit.sh and lib/modules/08_compliance_check.sh so
# both agree on the same setting.
sshd_effective_value() {
    local key="$1" value sshd_config="${SSHD_CONFIG:-/etc/ssh/sshd_config}"
    if command_exists sshd; then
        value=$(sshd -T 2>/dev/null | awk -v k="$key" 'tolower($1) == tolower(k) { $1=""; sub(/^ /,""); print; exit }')
    fi
    if [[ -z "$value" ]]; then
        value=$(grep -iE "^\s*${key}\s+" "$sshd_config" 2>/dev/null | awk '{print $2}' | tail -n1)
    fi
    echo "$value"
}
