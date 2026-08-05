#!/usr/bin/env bash
# 03_file_permissions.sh - Finds risky filesystem permissions: SUID/SGID
# binaries, world-writable files, unowned files, and loose permissions on
# security-critical config files.

# Directories excluded from filesystem-wide scans (virtual/pseudo filesystems
# and noisy paths that are not attacker-relevant).
readonly FS_SCAN_EXCLUDES=(-path /proc -o -path /sys -o -path /run -o -path /dev)

run_file_permissions_audit() {
    section "File Permission Audit"
    _check_suid_sgid_files
    _check_world_writable_files
    _check_unowned_files
    _check_critical_file_permissions
}

_check_suid_sgid_files() {
    local known_suid_allowlist='/usr/bin/sudo|/usr/bin/su|/usr/bin/passwd|/usr/bin/mount|/usr/bin/umount|/usr/bin/chsh|/usr/bin/chfn|/usr/bin/gpasswd|/usr/bin/newgrp|/usr/bin/pkexec|/usr/bin/fusermount3?'
    local suid_files
    suid_files=$(find / \( "${FS_SCAN_EXCLUDES[@]}" \) -prune -o -type f -perm -4000 -print 2>/dev/null)

    local unexpected=""
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        [[ "$f" =~ ^($known_suid_allowlist)$ ]] && continue
        unexpected+="$f "
    done <<< "$suid_files"

    if [[ -n "$unexpected" ]]; then
        add_finding "MEDIUM" "FilePermissions" "SUID binaries outside the expected allowlist" \
            "Files: $unexpected" \
            "Review each binary; remove the SUID bit (chmod u-s) if not required."
    else
        add_finding "INFO" "FilePermissions" "Only expected SUID binaries present" "" ""
    fi
}

_check_world_writable_files() {
    local ww_files
    ww_files=$(find / \( "${FS_SCAN_EXCLUDES[@]}" -o -path /tmp -o -path /var/tmp \) -prune \
        -o -type f -perm -0002 -print 2>/dev/null | head -n 50)

    if [[ -n "$ww_files" ]]; then
        local count
        count=$(echo "$ww_files" | wc -l)
        add_finding "HIGH" "FilePermissions" "World-writable file(s) found (showing up to 50)" \
            "$count+ files, e.g.: $(echo "$ww_files" | head -n 5 | tr '\n' ' ')" \
            "Remove world-write permission (chmod o-w) unless explicitly required."
    else
        add_finding "INFO" "FilePermissions" "No unexpected world-writable files found" "" ""
    fi
}

_check_unowned_files() {
    local unowned
    unowned=$(find / \( "${FS_SCAN_EXCLUDES[@]}" \) -prune \
        -o \( -nouser -o -nogroup \) -print 2>/dev/null | head -n 20)

    if [[ -n "$unowned" ]]; then
        add_finding "MEDIUM" "FilePermissions" "File(s) with no valid owner/group (showing up to 20)" \
            "$(echo "$unowned" | tr '\n' ' ')" \
            "Assign a valid owner/group or remove the file if it's a leftover from a deleted account."
    else
        add_finding "INFO" "FilePermissions" "No unowned files found" "" ""
    fi
}

_check_critical_file_permissions() {
    # path:max_octal_mode pairs for files that must not be more permissive than listed.
    local targets=(
        "/etc/passwd:644"
        "/etc/group:644"
        "/etc/shadow:640"
        "/etc/gshadow:640"
        "/etc/ssh/sshd_config:644"
        "/etc/sudoers:440"
        "/etc/crontab:644"
    )

    local entry path max_mode actual
    for entry in "${targets[@]}"; do
        path="${entry%%:*}"
        max_mode="${entry##*:}"
        [[ -e "$path" ]] || continue

        actual=$(stat -c '%a' "$path" 2>/dev/null)
        [[ -z "$actual" ]] && continue

        if (( 10#$actual > 10#$max_mode )); then
            add_finding "HIGH" "FilePermissions" "$path has permissions looser than recommended" \
                "Current: $actual, expected at most: $max_mode" \
                "Run: chmod $max_mode $path"
        else
            add_finding "INFO" "FilePermissions" "$path permissions are within policy ($actual)" "" ""
        fi
    done
}
