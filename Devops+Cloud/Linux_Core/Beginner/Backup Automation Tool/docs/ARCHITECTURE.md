# Architecture

## Design principle: config holds settings, lib holds logic, bin holds orchestration

- **`config/backup.conf`** - what to back up, where, and how often to keep it. No logic.
- **`lib/*.sh`** - reusable functions: validation, the actual tar/gzip/retention work, logging, reporting. No script here runs on its own.
- **`bin/*.sh`** - thin entry points. Each one sources the lib files it needs, loads config, and calls functions in the right order. No business logic lives here beyond sequencing.

This split is what lets you add a new check, a new report format, or point the tool at entirely different directories without touching more than one file.

## The backup flow

```
backup.sh
   |
   +-- load_config()               (lib/backup-functions.sh)
   +-- acquire_lock()               refuses to run if another backup is in progress
   +-- validate_backup_root()      (lib/validation.sh)
   +-- check_disk_space()          (lib/validation.sh)
   |
   +-- for each SOURCE_DIR:
   |      backup_single_directory()
   |         +-- validate_source_dir()
   |         +-- [optional] stage_with_rsync()
   |         +-- tar -czf  ->  .tar.gz.partial
   |         +-- validate_archive()   (integrity check via tar -tzf)
   |         +-- rename .partial -> final archive
   |         +-- apply_retention()    (only after a verified success)
   |
   +-- generate_summary_report()   (lib/report.sh)
   +-- release_lock()               (via trap, runs even on error)
```

## Why a lock file

If a manual backup is still running when cron's scheduled backup fires, two `tar` processes writing into the same `BACKUP_ROOT` at once is a real risk - at best wasted work, at worst a corrupted `.partial` file. `acquire_lock` uses `mkdir` as its primitive specifically because directory creation is atomic on every POSIX filesystem: when two processes race to create the same directory, exactly one succeeds. No extra dependency (like `flock`) is needed.

## Why `.partial` before the real filename

`tar` writes its output incrementally. If the process is killed (out of disk space, `Ctrl+C`, the EC2 instance rebooting) partway through, a file already sitting at the final `name_timestamp.tar.gz` path would look like a complete backup to every other part of the system - `list-backups.sh` would show it, `restore.sh` would offer to restore it. Writing to `<name>.tar.gz.partial` first and only renaming to the real name after `validate_archive` confirms it's intact means a failed backup can never masquerade as a successful one.

## Why retention only runs after a *verified* success

Rotation (`apply_retention`) is called from inside `backup_single_directory`, and only on the success path - after `validate_archive` has confirmed the new archive is real and intact. If today's backup attempt fails, the function returns early and retention never runs for that source. This matters: rotating based on a failed attempt could delete a good, restorable backup to make room for a broken one that doesn't even exist.

## Why retention groups by sanitized source name, not globally

Archives are named `<sanitized-source-name>_<timestamp>.tar.gz`. `apply_retention` only ever looks at files matching `<name>_*.tar.gz` for the specific source it just backed up. Without this, backing up four different directories into one shared `BACKUP_ROOT` would let a burst of `/home` backups crowd out and delete `/etc` backups that are nowhere near their own retention limit.

## Why `sanitize_source_name` uses the full path, not just the basename

`/var/www` and `/opt/www` share a basename (`www`) but are different directories. Sanitizing the *full* path (`/var/www` -> `var-www`, `/opt/www` -> `opt-www`) keeps every source's backup series distinct, at the cost of slightly longer names for deeply nested paths - a trade worth making, since a silent basename collision would be far worse than a long filename.

## The optional rsync staging path

When `USE_RSYNC_STAGING=true`, `stage_with_rsync` mirrors the source directory into `RSYNC_STAGING_DIR/<name>` with `rsync -a --delete` *before* `tar` runs, and `tar` then archives the staged copy instead of the live source. This exists for one specific situation: a source directory that changes very frequently (e.g. an active database's data files, or a busy upload directory), where `rsync`'s incremental sync produces a more consistent snapshot than `tar` reading directly from a directory that's mutating underneath it. For a typical source directory (config files, static web content, home directories) this adds complexity without a real benefit, which is why it's off by default. If `rsync` isn't installed, the function logs a warning and falls back to backing up the source directly rather than failing the whole run.

## Why log output goes to stderr, not stdout

Several functions (like `stage_with_rsync`) both log *and* return a value via `echo`, and are called as `result="$(some_function)"`. Command substitution captures a function's entire **stdout**. If log lines were written to stdout, they would be captured right along with the intended return value and corrupt it - this was a real bug caught during testing (see the regression test in `tests/test-backup.sh`). Routing all console log output to stderr means it's still visible in a terminal, but is never accidentally swept into a `$(...)` capture.

## What "logs" and "reports" are each for

- **Logs** (`logs/backup_<timestamp>.log`) are a complete diary of one run - every command attempted, every validation check, every error - written for someone debugging a specific failure.
- **Reports** (`reports/backup_report_<timestamp>.txt`) are a short, fixed-format summary - written for someone who just wants to know "did last night's backup work," without reading a diary.

## Restore is intentionally the mirror image of backup, with one extra guard

`restore.sh` follows: list -> select -> validate -> choose destination -> extract -> verify. The one safety rule that has no equivalent on the backup side: it refuses to extract into a destination that already contains files, specifically to prevent two different restores (or a restore and existing real data) from silently mixing together. There is no `--force` flag for this - choosing a different, empty destination is always the safe path.
