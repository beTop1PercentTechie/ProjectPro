#!/usr/bin/env bash
# backup-functions.sh - The core engine: configuration loading, timestamp
# generation, the actual tar+gzip work, size/duration measurement, and the
# retention (rotation) policy. bin/backup.sh orchestrates these; it does
# not implement any of this logic itself.

# --- Small shared helpers -----------------------------------------------------

command_exists() { command -v "$1" >/dev/null 2>&1; }

timestamp_now() { date '+%Y-%m-%d_%H-%M-%S'; }
human_date()    { date '+%Y-%m-%d %H:%M:%S %Z'; }

# human_readable_size <bytes> - e.g. 1572864 -> "1.50 MB"
human_readable_size() {
    local bytes="$1"
    awk -v b="$bytes" 'BEGIN {
        if (b >= 1073741824) printf "%.2f GB", b/1073741824;
        else if (b >= 1048576) printf "%.2f MB", b/1048576;
        else if (b >= 1024) printf "%.2f KB", b/1024;
        else printf "%d B", b;
    }'
}

# human_duration <seconds> - e.g. 125 -> "2m 5s"
human_duration() {
    local total="$1"
    awk -v s="$total" 'BEGIN {
        m = int(s/60); r = s - (m*60);
        if (m > 0) printf "%dm %ds", m, r; else printf "%ds", r;
    }'
}

# sanitize_source_name </some/path> - "/var/www" -> "var-www", "/" -> "root".
# This is the prefix every archive for that source is named with, so it
# must be stable and collision-resistant across different source paths.
sanitize_source_name() {
    local path="$1" name
    name="${path#/}"
    name="${name%/}"
    name="${name//\//-}"
    name="${name// /_}"
    [[ -z "$name" ]] && name="root"
    echo "$name"
}

# --- Configuration ---------------------------------------------------------

# load_config <config_file> - sources the config file and fills in safe
# defaults for anything it doesn't set, so the rest of the tool never has
# to guard against an unset variable.
load_config() {
    local config_file="$1"

    if [[ -f "$config_file" ]]; then
        # shellcheck disable=SC1090
        source "$config_file"
    else
        echo "Config file not found: $config_file (using built-in defaults)" >&2
    fi

    : "${SOURCE_DIRS:=}"
    : "${BACKUP_ROOT:=$BAT_HOME/backups}"
    : "${RETENTION_COUNT:=7}"
    : "${LOG_DIR:=$BAT_HOME/logs}"
    : "${REPORT_DIR:=$BAT_HOME/reports}"
    : "${MIN_FREE_DISK_MB:=200}"
    : "${LOCK_FILE:=$BAT_HOME/.backup.lock}"
    : "${TAR_EXCLUDES:=}"
    : "${USE_RSYNC_STAGING:=false}"
    : "${RSYNC_STAGING_DIR:=$BAT_HOME/.rsync-staging}"

    export SOURCE_DIRS BACKUP_ROOT RETENTION_COUNT LOG_DIR REPORT_DIR
    export MIN_FREE_DISK_MB LOCK_FILE TAR_EXCLUDES
    export USE_RSYNC_STAGING RSYNC_STAGING_DIR
}

# --- Overlap protection -----------------------------------------------------

# acquire_lock - refuses to start if another run is already in progress.
# Uses "mkdir" as the lock primitive: mkdir is atomic on every POSIX
# filesystem (two processes racing to create the same directory, exactly
# one wins), so this needs no extra dependency like flock.
acquire_lock() {
    if ! mkdir "$LOCK_FILE" 2>/dev/null; then
        log_error "Another backup run appears to be in progress (lock held: $LOCK_FILE)"
        log_error "If no backup is actually running, remove the lock directory manually and retry."
        return 1
    fi
    echo "$$" > "$LOCK_FILE/pid"
    return 0
}

release_lock() {
    rm -rf -- "$LOCK_FILE"
}

# --- The actual backup work -------------------------------------------------

# stage_with_rsync <source_dir> <sanitized_name>
# Mirrors <source_dir> into RSYNC_STAGING_DIR/<name> with rsync, and prints
# the staged path on success. Used when USE_RSYNC_STAGING=true, as an
# alternative to tar reading directly from the live source directory - see
# docs/ARCHITECTURE.md for when this is actually worth enabling.
stage_with_rsync() {
    local source_dir="$1" name="$2" staged_path="${RSYNC_STAGING_DIR}/${name}"

    if ! command_exists rsync; then
        log_warn "USE_RSYNC_STAGING is true but 'rsync' is not installed - backing up the source directly instead"
        echo "$source_dir"
        return 0
    fi

    ensure_dir "$staged_path" || return 1

    if ! rsync -a --delete "${source_dir%/}/" "${staged_path%/}/" >>"$LOG_FILE" 2>&1; then
        log_error "rsync staging failed for $source_dir"
        return 1
    fi

    echo "$staged_path"
    return 0
}

# backup_single_directory <source_dir> <timestamp>
# Creates, verifies, and retains one source directory's archive. Returns
# 0 on success (with SOURCE_ARCHIVE_SIZE_BYTES set) or 1 on failure.
backup_single_directory() {
    local source_dir="$1" ts="$2"
    local name archive tmp_archive tar_args=() tar_source_dir="$source_dir"

    validate_source_dir "$source_dir" || return 1

    name="$(sanitize_source_name "$source_dir")"
    archive="${BACKUP_ROOT}/${name}_${ts}.tar.gz"
    tmp_archive="${archive}.partial"

    if [[ "${USE_RSYNC_STAGING:-false}" == "true" ]]; then
        tar_source_dir="$(stage_with_rsync "$source_dir" "$name")" || return 1
    fi

    if [[ -n "$TAR_EXCLUDES" ]]; then
        local IFS=','
        local pattern
        for pattern in $TAR_EXCLUDES; do
            tar_args+=(--exclude="$pattern")
        done
    fi

    log_info "Backing up $source_dir -> $(basename "$archive")"

    if [[ "${VERBOSE:-false}" == "true" ]]; then
        log_info "  tar -czf $tmp_archive ${tar_args[*]} -C $(dirname "$tar_source_dir") $(basename "$tar_source_dir")"
    fi

    # Write to a .partial name first, then rename on success, so a backup
    # that dies partway through never leaves a file that looks finished.
    if ! tar -czf "$tmp_archive" "${tar_args[@]}" -C "$(dirname "$tar_source_dir")" "$(basename "$tar_source_dir")" 2>>"$LOG_FILE"; then
        log_error "tar/gzip failed for $source_dir"
        rm -f -- "$tmp_archive"
        return 1
    fi

    mv -- "$tmp_archive" "$archive"

    if ! validate_archive "$archive"; then
        log_error "New archive failed verification, removing it: $archive"
        rm -f -- "$archive"
        return 1
    fi

    SOURCE_ARCHIVE_SIZE_BYTES=$(stat -c '%s' "$archive" 2>/dev/null || echo 0)
    log_success "Backed up $source_dir (name: $name, size: $(human_readable_size "$SOURCE_ARCHIVE_SIZE_BYTES"))"

    # Retention only ever runs after a verified, successful new backup -
    # a failed attempt must never trigger rotation of the good backups
    # that already exist.
    apply_retention "$name"

    return 0
}

# apply_retention <sanitized_source_name>
# Keeps the newest RETENTION_COUNT archives for this source and deletes
# the rest, oldest first. Deletion is always by an explicit, validated
# file path - never a wildcard expansion handed straight to rm.
apply_retention() {
    local name="$1" listing total index=0 mtime path

    (( RETENTION_COUNT <= 0 )) && return 0

    listing="$(find "$BACKUP_ROOT" -maxdepth 1 -type f -name "${name}_*.tar.gz" -printf '%T@ %p\n' 2>/dev/null | sort -rn)"
    [[ -z "$listing" ]] && return 0

    total=$(wc -l <<< "$listing")
    if (( total <= RETENTION_COUNT )); then
        return 0
    fi

    log_info "Retention: $total backup(s) for '$name', keeping newest $RETENTION_COUNT"

    while IFS=' ' read -r mtime path; do
        index=$((index + 1))
        (( index <= RETENTION_COUNT )) && continue
        [[ -z "$path" || ! -f "$path" ]] && continue

        rm -f -- "$path"
        log_info "Retention: removed old backup $(basename "$path")"
        REMOVED_COUNT=$(( ${REMOVED_COUNT:-0} + 1 ))
    done <<< "$listing"
}
