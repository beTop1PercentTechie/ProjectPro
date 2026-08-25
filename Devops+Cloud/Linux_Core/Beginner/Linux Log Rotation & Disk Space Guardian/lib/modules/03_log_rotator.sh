#!/usr/bin/env bash
# 03_log_rotator.sh - Requirement #3: safe auto-rotation and compression of
# logs that exceed a size/age policy.
#
# "Safe" here means:
#   - never follow symlinks or touch non-regular files
#   - never touch a file that was modified within ROTATION_QUIET_PERIOD_SEC
#     (it may be mid-write)
#   - copy-then-truncate (rather than move) so a process holding the
#     original file descriptor open keeps writing to the same inode - the
#     same tradeoff logrotate's own `copytruncate` option makes
#   - every rotation/compression/deletion is recorded through log_action()
#     so there is always an audit trail of what the agent did
#   - DRY_RUN=true runs the same decision logic without touching any file

run_log_rotator() {
    section "Log Rotation & Compression"

    shopt -s nullglob globstar 2>/dev/null

    local rules
    mapfile -t rules < <(_load_rotation_rules)

    if [[ ${#rules[@]} -eq 0 ]]; then
        log_warn "No rotation rules loaded from $ROTATION_POLICY_FILE"
    fi

    # SEEN_FILES tracks every file already evaluated so a broader later rule
    # (or the DEFAULT_* fallback) never re-processes a file a more specific
    # earlier rule already handled.
    local seen_file
    seen_file="$(mktemp "${GUARDIAN_TMP_DIR:-/tmp}/guardian_seen.XXXXXX")"

    local rule pattern max_size max_age keep_count compress
    for rule in "${rules[@]}"; do
        IFS='|' read -r pattern max_size max_age keep_count compress <<< "$rule"
        _apply_rule_to_pattern "$pattern" "$max_size" "$max_age" "$keep_count" "$compress" "$seen_file"
    done

    _apply_rule_to_pattern "$DEFAULT_LOG_PATTERN" "$DEFAULT_MAX_SIZE_MB" "$DEFAULT_MAX_AGE_DAYS" \
        "$DEFAULT_KEEP_COUNT" "$DEFAULT_COMPRESS" "$seen_file"

    rm -f "$seen_file"
}

# _load_rotation_rules - prints non-comment, non-blank lines from the
# rotation policy file.
_load_rotation_rules() {
    [[ -f "$ROTATION_POLICY_FILE" ]] || return 0
    grep -vE '^\s*(#|$)' "$ROTATION_POLICY_FILE"
}

_apply_rule_to_pattern() {
    local pattern="$1" max_size="$2" max_age="$3" keep_count="$4" compress="$5" seen_file="$6"
    local file

    for file in $pattern; do
        [[ -e "$file" ]] || continue
        grep -qxF "$file" "$seen_file" 2>/dev/null && continue
        echo "$file" >> "$seen_file"

        _is_already_rotated "$file" && continue
        _evaluate_file "$file" "$max_size" "$max_age" "$keep_count" "$compress"
    done
}

# _is_already_rotated <file> - true if the file looks like a rotation
# artifact this agent (or logrotate) already produced, so it never gets
# rotated again.
_is_already_rotated() {
    local file="$1"
    [[ "$file" == *.gz ]] && return 0
    [[ "$file" =~ \.[0-9]{8}-[0-9]{6}$ ]] && return 0
    return 1
}

_evaluate_file() {
    local file="$1" max_size_mb="$2" max_age_days="$3" keep_count="$4" compress="$5"

    [[ -f "$file" && ! -L "$file" ]] || return

    local size_bytes mtime_epoch now age_days size_mb
    size_bytes=$(stat -c '%s' "$file" 2>/dev/null) || return
    mtime_epoch=$(stat -c '%Y' "$file" 2>/dev/null) || return
    now=$(epoch_now)
    age_days=$(( (now - mtime_epoch) / 86400 ))
    size_mb=$(( size_bytes / 1048576 ))

    local trigger=""
    if (( max_size_mb > 0 && size_mb >= max_size_mb )); then
        trigger="size ${size_mb}MB >= ${max_size_mb}MB"
    elif (( max_age_days > 0 && age_days >= max_age_days )); then
        trigger="age ${age_days}d >= ${max_age_days}d"
    fi

    [[ -z "$trigger" ]] && return

    if (( (now - mtime_epoch) < ROTATION_QUIET_PERIOD_SEC )); then
        log_action "SKIP" "$file" "$size_bytes" "$size_bytes" \
            "trigger matched ($trigger) but file was modified within the last ${ROTATION_QUIET_PERIOD_SEC}s - deferring"
        return
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        add_event "INFO" "Rotation" "[DRY-RUN] Would rotate $file" "trigger: $trigger, size: $(bytes_to_human "$size_bytes")"
        return
    fi

    _rotate_file "$file" "$size_bytes" "$trigger" "$compress"
    _prune_old_rotations "$file" "$keep_count"
}

# _rotate_file <file> <size_bytes> <trigger_reason> <compress>
_rotate_file() {
    local file="$1" size_bytes="$2" trigger="$3" compress="$4"
    local stamp rotated
    stamp="$(date '+%Y%m%d-%H%M%S')"
    rotated="${file}.${stamp}"

    if ! cp -p "$file" "$rotated" 2>/dev/null; then
        add_event "WARNING" "Rotation" "Failed to copy $file for rotation" "Skipped - original file left untouched"
        return
    fi

    # Truncate in place (copytruncate) so a process with the file already
    # open keeps writing to the same inode instead of a now-orphaned one.
    : > "$file"

    local final_path="$rotated" after_bytes=0
    if [[ "$compress" == "true" ]]; then
        if gzip -f "$rotated" 2>/dev/null; then
            final_path="${rotated}.gz"
        fi
    fi

    log_action "ROTATE" "$file" "$size_bytes" "$after_bytes" \
        "trigger: $trigger -> archived as $(basename "$final_path")"
}

# _prune_old_rotations <base_file> <keep_count> - deletes rotated copies of
# <base_file> beyond the configured retention count, oldest first.
_prune_old_rotations() {
    local base_file="$1" keep_count="$2" dir base
    dir="$(dirname "$base_file")"
    base="$(basename "$base_file")"

    local listing
    listing="$(find "$dir" -maxdepth 1 -type f -name "${base}.*" -printf '%T@ %p\n' 2>/dev/null | sort -rn)"
    [[ -z "$listing" ]] && return

    local index=0 mtime f size
    while IFS=' ' read -r mtime f; do
        index=$((index + 1))
        (( index <= keep_count )) && continue

        size=$(stat -c '%s' "$f" 2>/dev/null || echo 0)
        if [[ "$DRY_RUN" == "true" ]]; then
            add_event "INFO" "Rotation" "[DRY-RUN] Would delete old rotation $f" "$(bytes_to_human "$size"), beyond retention of $keep_count"
        else
            rm -f "$f"
            log_action "DELETE_OLD_ROTATION" "$f" "$size" 0 "beyond retention of $keep_count rotated copies for $base"
        fi
    done <<< "$listing"
}
