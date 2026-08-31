#!/usr/bin/env bash
# validation.sh - Pre-flight checks. Every one of these runs *before* the
# tool touches a filesystem, so failures are caught early with a clear
# message instead of surfacing as a cryptic tar/gzip error mid-backup.

# validate_source_dir <path> - true if <path> exists, is a directory, and
# is readable by this process. Logs the specific reason on failure.
validate_source_dir() {
    local dir="$1"

    if [[ -z "$dir" ]]; then
        log_error "Source directory is empty in configuration - skipping"
        return 1
    fi
    if [[ ! -e "$dir" ]]; then
        log_error "Source does not exist: $dir"
        return 1
    fi
    if [[ ! -d "$dir" ]]; then
        log_error "Source is not a directory: $dir"
        return 1
    fi
    if [[ ! -r "$dir" ]]; then
        log_error "Source is not readable (permission denied): $dir"
        return 1
    fi

    return 0
}

# validate_backup_root <path> - ensures the backup destination exists (or
# can be created) and is writable. This is where archives get written, so
# failing here must stop the run before any tar/gzip work begins.
validate_backup_root() {
    local dir="$1"

    if [[ -z "$dir" ]]; then
        log_error "BACKUP_ROOT is not set in configuration"
        return 1
    fi

    if [[ ! -d "$dir" ]]; then
        if ! mkdir -p -- "$dir" 2>/dev/null; then
            log_error "Could not create backup destination: $dir"
            return 1
        fi
        log_info "Created backup destination: $dir"
    fi

    if [[ ! -w "$dir" ]]; then
        log_error "Backup destination is not writable: $dir"
        return 1
    fi

    return 0
}

# ensure_dir <path> - create a directory tree if missing, with a clear
# error if that fails (e.g. permission denied on the parent).
ensure_dir() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        return 0
    fi
    if ! mkdir -p -- "$dir" 2>/dev/null; then
        log_error "Could not create directory: $dir"
        return 1
    fi
    return 0
}

# check_disk_space <path> <min_free_mb> - true if the filesystem holding
# <path> has at least <min_free_mb> megabytes free. Prevents starting a
# backup that's guaranteed to fail partway through with a full disk.
check_disk_space() {
    local dir="$1" min_free_mb="$2" available_kb available_mb

    command_exists df || return 0
    (( min_free_mb <= 0 )) && return 0

    available_kb=$(df -Pk "$dir" 2>/dev/null | tail -n +2 | awk '{print $4}')
    if [[ -z "$available_kb" ]]; then
        log_warn "Could not determine free disk space for $dir - continuing anyway"
        return 0
    fi

    available_mb=$(( available_kb / 1024 ))
    if (( available_mb < min_free_mb )); then
        log_error "Not enough disk space at $dir: ${available_mb}MB free, need at least ${min_free_mb}MB"
        return 1
    fi

    return 0
}

# validate_archive <path> - true if a .tar.gz file is structurally intact.
# A backup that "completed" but produced a corrupt archive is worse than
# an obvious failure, because nobody notices until the day they need it.
validate_archive() {
    local archive="$1"

    if [[ ! -f "$archive" ]]; then
        log_error "Archive not found: $archive"
        return 1
    fi
    if [[ ! -s "$archive" ]]; then
        log_error "Archive is empty (0 bytes): $archive"
        return 1
    fi
    if ! tar -tzf "$archive" >/dev/null 2>&1; then
        log_error "Archive failed integrity check (corrupt or incomplete): $archive"
        return 1
    fi

    return 0
}
