#!/usr/bin/env bash
# 02_space_hogs.sh - Requirement #2: automatically identify the exact
# directories and files consuming the most disk space, using du and find.

run_space_hogs() {
    section "Space Consumer Analysis"

    local IFS=','
    local path
    for path in $SCAN_PATHS; do
        path="$(trim "$path")"
        [[ -z "$path" ]] && continue
        [[ -d "$path" ]] || { log_debug "Scan path does not exist, skipping: $path"; continue; }
        _top_directories "$path"
        _large_files "$path"
    done
}

# _top_directories <path> - the N largest subdirectories under <path>,
# one level of du summary at DU_MAX_DEPTH.
_top_directories() {
    local path="$1"
    command_exists du || { log_warn "'du' not found - skipping directory scan"; return; }

    local top
    top="$(du -x -k --max-depth="$DU_MAX_DEPTH" "$path" 2>/dev/null \
        | sort -rn \
        | head -n "$TOP_N_CONSUMERS")"

    [[ -z "$top" ]] && return

    local rank=0 kb dir
    while IFS=$'\t' read -r kb dir; do
        [[ -z "$dir" ]] && continue
        rank=$((rank + 1))
        add_event "INFO" "SpaceHogs" "#${rank} directory under ${path}: $dir" "$(kb_to_human "$kb") used"
    done <<< "$top"
}

# _large_files <path> - individual files over LARGE_FILE_SIZE_MB, largest
# first, using find (fast) rather than a second recursive du pass.
_large_files() {
    local path="$1"
    command_exists find || { log_warn "'find' not found - skipping large-file scan"; return; }

    local large
    large="$(find "$path" -xdev -type f -size "+${LARGE_FILE_SIZE_MB}M" -printf '%s\t%p\n' 2>/dev/null \
        | sort -rn \
        | head -n "$TOP_N_CONSUMERS")"

    [[ -z "$large" ]] && return

    local rank=0 bytes file
    while IFS=$'\t' read -r bytes file; do
        [[ -z "$file" ]] && continue
        rank=$((rank + 1))
        add_event "INFO" "SpaceHogs" "#${rank} large file under ${path}: $file" "$(bytes_to_human "$bytes")"
    done <<< "$large"
}
